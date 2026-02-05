module raise_child::need;

use raise_child::manage::{Manage, AdminCap, is_sponsor_added, add_sponsor_to_manage};
use raise_child::pool::{
    VndPool,
    LocalPool,
    PoolWithdrawDao,
    WithDrawProposal,
    mint_vnd,
    get_local_pool_region,
    add_amount_to_local_pool,
    get_withdraw_proposal_close_period,
    get_withdraw_dao_min_approve_rate,
    get_withdraw_dao_min_voters,
    get_withdraw_proposal_approvers_number,
    get_withdraw_proposal_refusers_number,
    create_withdraw_proposal_for_special_need,
    calculate_withdraw_aprroval_ratio,
    get_withdraw_proposal_execute_status,
    split_vnd,
    set_withdraw_proposal_executed,
    get_withdraw_proposal_amount,
    get_withdraw_proposal_description,
    get_withdraw_proposal_id,
    create_withdraw_proposal_for_books_need
};
use raise_child::record::create_tx_record_v2;
use raise_child::sponsor::{
    SponsorNFT,
    mint_sponsor_nft_v2,
    update_donation_after_donate,
    get_sponsor_id,
    get_sponsor_donate_amount,
    mint_sponsor_nft
};
use std::string::String;
use std::vector::push_back;
use sui::clock::{Self, Clock};

const ENotMatchedAmount: u64 = 1;
const ENeedSupported: u64 = 2;
const EInvalidSupportValue: u64 = 3;
const EPassPeriod: u64 = 4;
const EInsufficientAmount: u64 = 5;
const EProposalConfirmed: u64 = 6;
const EProposalOwnerVote: u64 = 7;
const EAlreadyVoteProposal: u64 = 8;
const EProposalStillPending: u64 = 9;
const EProposalApproveRateNotPass: u64 = 10;
const ENotEnoughVoters: u64 = 11;
const EDonationPassTarget: u64 = 12;
const EWithdrawProposalExecuted: u64 = 13;
const EWithdrawProposalNotOfCampaign: u64 = 14;
const ENeedHasBeenFunded: u64 = 15;
const EWithdrawProposalNotOfNeed: u64 = 16;

const MIN_SPECIAL_NEED_TARGET: u128 = 100_000;
const PRESISION_FACTOR: u128 = 1_000;

public struct SpecialNeedDao has key {
    id: UID,
    min_approved_rate: u128,
    min_voters: u64,
}

public struct BooksNeed has key {
    id: UID,
    year: u64,
    year_changes: vector<u64>,
    semester: u64,
    value: u128,
    sponsors: vector<ID>,
    donations: vector<ID>,
    withdraw_proposals: vector<ID>,
    withdraws_for_need: vector<ID>,
}

public struct MealSupportDuration has store {
    start_period: String,
    end_period: String,
}

public struct MealNeed has key {
    id: UID,
    year: u64,
    value: u128,
    sponsors: vector<ID>,
    donations: vector<ID>,
    durations: vector<MealSupportDuration>,
    withdraw_proposals: vector<ID>,
    withdraws_for_need: vector<ID>,
}

public struct SpecialNeedProposal has key {
    id: UID,
    child: ID,
    creator: address,
    target: u128,
    description: String,
    approvers: vector<address>,
    refusers: vector<address>,
    approve_weight: u128,
    refuse_weight: u128,
    refuse_reasons: vector<String>,
    approved_periods: vector<u64>,
    refused_periods: vector<u64>,
    is_confirm: bool,
    created_at: u64,
    updated_at: u64,
    closed_at: u64,
}

public struct SpecialNeedCampaign has key {
    id: UID,
    child: ID,
    creator: address,
    target: u128,
    description: String,
    total_donated: u128,
    withdraw_amount: u128,
    donations: vector<ID>,
    withdraws: vector<ID>,
    withdraw_proposals: vector<ID>,
    created_at: u64,
    updated_at: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(SpecialNeedDao {
        id: object::new(ctx),
        min_approved_rate: 8_000, // 80%
        min_voters: 10,
    });
}

public fun edit_special_need_dao_rate(
    _: &AdminCap,
    dao: &mut SpecialNeedDao,
    min_rate: u128,
    min_voters: u64,
) {
    if (min_rate > 0) {
        dao.min_approved_rate = min_rate;
    };

    if (min_voters > 0) {
        dao.min_voters = min_voters;
    };
}

public(package) fun init_books_need(semester: u64, year: u64, ctx: &mut TxContext): ID {
    let need = BooksNeed {
        id: object::new(ctx),
        year: year,
        year_changes: vector[year],
        semester: semester,
        value: 0,
        sponsors: vector[],
        donations: vector[],
        withdraw_proposals: vector[],
        withdraws_for_need: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun init_meal_need(year: u64, ctx: &mut TxContext): ID {
    let need = MealNeed {
        id: object::new(ctx),
        year: year,
        value: 0,
        sponsors: vector[],
        donations: vector[],
        durations: vector[],
        withdraw_proposals: vector[],
        withdraws_for_need: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun support_books_need(
    need: &mut BooksNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    sponsor: &mut SponsorNFT,
    amount: u128,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(amount == need.value, ENotMatchedAmount);
    assert!(vector::length(&need.donations) < vector::length(&need.year_changes), ENeedSupported);

    let sponsor_id: ID;
    if (!is_sponsor_added(manage, ctx)) {
        sponsor_id =
            mint_sponsor_nft_v2(
                manage,
                first_name,
                last_name,
                gender,
                phone_number,
                email,
                amount,
                ctx,
            );
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
        sponsor_id = get_sponsor_id(sponsor);
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    vector::push_back(
        &mut need.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support book need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
    vector::push_back(&mut need.sponsors, sponsor_id);
}

public(package) fun support_meal_need(
    need: &mut MealNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    sponsor: &mut SponsorNFT,
    amount: u128,
    start_period: String,
    end_period: String,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let supported_months = amount / need.value;
    assert!(supported_months >= 1 && supported_months <= 12, EInvalidSupportValue);

    let sponsor_id: ID;
    if (!is_sponsor_added(manage, ctx)) {
        sponsor_id =
            mint_sponsor_nft_v2(
                manage,
                first_name,
                last_name,
                gender,
                phone_number,
                email,
                amount,
                ctx,
            );
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
        sponsor_id = get_sponsor_id(sponsor);
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    vector::push_back(
        &mut need.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support book need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
    vector::push_back(&mut need.sponsors, sponsor_id);
    vector::push_back(
        &mut need.durations,
        MealSupportDuration { start_period: start_period, end_period: end_period },
    );
}

public(package) fun create_special_need_proposal(
    child_id: ID,
    target: u128,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);
    assert!(target >= MIN_SPECIAL_NEED_TARGET, EInsufficientAmount);

    let proposal = SpecialNeedProposal {
        id: object::new(ctx),
        child: child_id,
        creator: ctx.sender(),
        target: target,
        description: description,
        approvers: vector[],
        refusers: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        refuse_reasons: vector[],
        approved_periods: vector[],
        refused_periods: vector[],
        is_confirm: false,
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    transfer::share_object(proposal);
    id
}

public fun vote_special_need_proposal(
    proposal: &mut SpecialNeedProposal,
    sponsor: &mut SponsorNFT,
    dao: &mut SpecialNeedDao,
    is_approve: bool,
    refuse_reason: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(!proposal.is_confirm, EProposalConfirmed);
    assert!(proposal.closed_at >= cur_time, EPassPeriod);

    let sender = ctx.sender();
    assert!(proposal.creator != sender, EProposalOwnerVote);

    let (approve_found, _) = vector::index_of(&mut proposal.approvers, &sender);
    let (refuse_found, _) = vector::index_of(&mut proposal.refusers, &sender);
    assert!(!approve_found && !refuse_found, EAlreadyVoteProposal);

    if (is_approve) {
        vector::push_back(&mut proposal.approvers, sender);
        proposal.approve_weight = proposal.approve_weight + get_sponsor_donate_amount(sponsor, ctx);
        vector::push_back(&mut proposal.approved_periods, cur_time);
    } else {
        vector::push_back(&mut proposal.refusers, sender);
        proposal.refuse_weight = proposal.refuse_weight + get_sponsor_donate_amount(sponsor, ctx);
        vector::push_back(&mut proposal.refuse_reasons, refuse_reason);
        vector::push_back(&mut proposal.refused_periods, cur_time);
    };

    proposal.updated_at = cur_time;
}

public(package) fun create_special_need_campaign(
    proposal: &mut SpecialNeedProposal,
    dao: &mut SpecialNeedDao,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(proposal.closed_at <= cur_time, EProposalStillPending);
    assert!(
        calculate_aprroval_ratio(proposal) >= dao.min_approved_rate,
        EProposalApproveRateNotPass,
    );
    assert!(
        vector::length(&proposal.approvers) + vector::length(&proposal.refusers) >= dao.min_voters,
        ENotEnoughVoters,
    );
    assert!(!proposal.is_confirm, EProposalConfirmed);
    proposal.is_confirm = true;

    let campaign = SpecialNeedCampaign {
        id: object::new(ctx),
        child: proposal.child,
        creator: proposal.creator,
        target: proposal.target,
        description: proposal.description,
        total_donated: 0,
        withdraw_amount: 0,
        donations: vector[],
        withdraws: vector[],
        withdraw_proposals: vector[],
        created_at: cur_time,
        updated_at: cur_time,
    };

    let id = campaign.id.to_inner();
    transfer::share_object(campaign);
    id
}

public(package) fun support_special_need_campaign(
    campaign: &mut SpecialNeedCampaign,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    sponsor: &mut SponsorNFT,
    amount: u128,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(campaign.total_donated + amount <= campaign.target, EDonationPassTarget);

    if (!is_sponsor_added(manage, ctx)) {
        mint_sponsor_nft(
            manage,
            first_name,
            last_name,
            gender,
            phone_number,
            email,
            amount,
            ctx,
        );
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    vector::push_back(
        &mut campaign.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support special need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
}

public(package) fun withdraw_from_campaign(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    campaign: &mut SpecialNeedCampaign,
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        &mut campaign.withdraw_proposals,
        &get_withdraw_proposal_id(proposal),
    );
    assert!(found, EWithdrawProposalNotOfCampaign);

    let cur_time = clock::timestamp_ms(clock);
    assert!(get_withdraw_proposal_close_period(proposal) <= cur_time, EProposalStillPending);
    assert!(
        calculate_withdraw_aprroval_ratio(proposal) >= get_withdraw_dao_min_approve_rate(dao),
        EProposalApproveRateNotPass,
    );
    assert!(!get_withdraw_proposal_execute_status(proposal), EWithdrawProposalExecuted);

    split_vnd(pool, proposal, ctx);
    set_withdraw_proposal_executed(proposal, cur_time);

    campaign.withdraw_amount = campaign.withdraw_amount + get_withdraw_proposal_amount(proposal);
    vector::push_back(
        &mut campaign.withdraws,
        create_tx_record_v2(
            get_withdraw_proposal_amount(proposal),
            b"VND".to_string(),
            b"Withdraw".to_string(),
            get_local_pool_region(local_pool),
            get_withdraw_proposal_description(proposal),
            clock,
            ctx,
        ),
    );
}

public(package) fun create_withdraw_proposal(
    campaign: &mut SpecialNeedCampaign,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u128,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let budget = campaign.total_donated - campaign.withdraw_amount;
    assert!(withdraw_amount <= budget, EInsufficientAmount);
    vector::push_back(
        &mut campaign.withdraw_proposals,
        create_withdraw_proposal_for_special_need(
            pool,
            local_pool,
            withdraw_amount,
            description,
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_books_need_withdraw_proposal(
    need: &mut BooksNeed,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        vector::length(&need.donations) > vector::length(&need.withdraws_for_need),
        ENeedHasBeenFunded,
    );

    vector::push_back(
        &mut need.withdraw_proposals,
        create_withdraw_proposal_for_books_need(
            pool,
            local_pool,
            need.value,
            description,
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun withdraw_from_books_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        &mut need.withdraw_proposals,
        &get_withdraw_proposal_id(proposal),
    );
    assert!(found, EWithdrawProposalNotOfNeed);

    let cur_time = clock::timestamp_ms(clock);
    assert!(get_withdraw_proposal_close_period(proposal) <= cur_time, EProposalStillPending);
    assert!(
        calculate_withdraw_aprroval_ratio(proposal) >= get_withdraw_dao_min_approve_rate(dao),
        EProposalApproveRateNotPass,
    );
    assert!(!get_withdraw_proposal_execute_status(proposal), EWithdrawProposalExecuted);

    split_vnd(pool, proposal, ctx);
    set_withdraw_proposal_executed(proposal, cur_time);
    vector::push_back(
        &mut need.withdraws_for_need,
        create_tx_record_v2(
            get_withdraw_proposal_amount(proposal),
            b"VND".to_string(),
            b"Withdraw".to_string(),
            get_local_pool_region(local_pool),
            get_withdraw_proposal_description(proposal),
            clock,
            ctx,
        ),
    );
}

public(package) fun get_books_need_id(need: &mut BooksNeed): ID {
    need.id.to_inner()
}

public(package) fun get_meal_need_id(need: &mut MealNeed): ID {
    need.id.to_inner()
}

public(package) fun calculate_aprroval_ratio(proposal: &mut SpecialNeedProposal): u128 {
    let total = proposal.approve_weight + proposal.refuse_weight;
    if (total == 0) return 0;

    (proposal.approve_weight * PRESISION_FACTOR) / total
}

public(package) fun get_special_need_proposal_creator(proposal: &mut SpecialNeedProposal): address {
    proposal.creator
}

public(package) fun get_special_need_proposal_id(proposal: &mut SpecialNeedProposal): ID {
    proposal.id.to_inner()
}

public(package) fun get_special_need_campaign_id(campaign: &mut SpecialNeedCampaign): ID {
    campaign.id.to_inner()
}
