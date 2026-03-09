module raise_child::need;

use raise_child::donor::{
    DonorNFT,
    mint_donor_nft_v2,
    update_donation_after_donate,
    get_donor_id,
    get_donor_donate_amount,
    mint_donor_nft
};
use raise_child::manage::{Manage, AdminCap, is_donor_added, add_donor_to_manage};
use raise_child::pool::{
    VndPool,
    LocalPool,
    PoolWithdrawDao,
    WithdrawProposal,
    mint_vnd,
    get_local_pool_region,
    add_amount_to_local_pool,
    get_withdraw_proposal_close_period,
    get_withdraw_dao_min_approve_rate,
    get_withdraw_dao_min_voters,
    get_withdraw_proposal_approvers_number,
    get_withdraw_proposal_refusers_number,
    calculate_withdraw_aprroval_ratio,
    get_withdraw_proposal_execute_status,
    split_vnd,
    set_withdraw_proposal_executed,
    get_withdraw_proposal_amount,
    get_withdraw_proposal_description,
    get_withdraw_proposal_id,
    create_withdraw_proposal_for_child_need,
    set_transaction_record_for_withdraw_proposal,
    create_withdraw_proposal_for_child_need_v2
};
use raise_child::record::create_tx_record_v2;
use std::string::String;
use std::vector::push_back;
use sui::clock::{Self, Clock};
use sui::table::{Self, Table};
use sui::vec_map::{Self, VecMap};

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
const EInvalidSupportMonths: u64 = 17;
const EChildProvidedMeal: u64 = 18;

const MIN_SPECIAL_NEED_TARGET: u64 = 100_000;
const PRESISION_FACTOR: u64 = 1_000;

public struct SpecialNeedDao has key {
    id: UID,
    min_approved_rate: u64,
    min_voters: u64,
}

public struct BooksNeed has key {
    id: UID,
    child: ID,
    year: u64,
    year_changes: vector<u64>,
    semester: u64,
    value: u64,
    donors: vector<ID>,
    donations: vector<ID>,
    withdraw_proposals: vector<ID>,
    withdraws_for_need: vector<ID>,
}

public struct MealSupportDuration has store {
    start_period: String,
    end_period: String,
}

/// Table ver
// public struct MealNeed has key {
//     id: UID,
//     year: u64,
//     value: u64,
//     donors: vector<ID>,
//     donations: vector<ID>,
//     durations: vector<MealSupportDuration>,
//     total_supported_months: u64,
//     supported_years: Table<u64, u64>,
//     withdraw_proposals: vector<ID>,
//     withdraws_for_need: vector<ID>,
// }

public struct MealNeed has key {
    id: UID,
    child: ID,
    year: u64,
    value: u64,
    donors: vector<ID>,
    donations: vector<ID>,
    durations: vector<MealSupportDuration>,
    total_supported_months: u64,
    supported_years: VecMap<u64, u64>,
    provide_meal_dates: vector<String>,
    provide_meal_periods: vector<u64>,
    provide_meal_staffs: vector<address>,
    withdraw_proposals: vector<ID>,
    withdraws_for_need: vector<ID>,
}

public struct HealthInsuranceNeed has key {
    id: UID,
    child: ID,
    year: u64,
    year_changes: vector<u64>,
    value: u64,
    donors: vector<ID>,
    donations: vector<ID>,
    withdraw_proposals: vector<ID>,
    withdraws_for_need: vector<ID>,
}

public struct SpecialNeedProposal has key {
    id: UID,
    child: ID,
    creator: address,
    target: u64,
    description: String,
    approvers: vector<address>,
    refusers: vector<address>,
    approve_weight: u64,
    refuse_weight: u64,
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
    target: u64,
    description: String,
    total_donated: u64,
    withdraw_amount: u64,
    donations: vector<ID>,
    withdraws: vector<ID>,
    withdraw_proposals: vector<ID>,
    created_at: u64,
    updated_at: u64,
}

public struct BooksNeedWithdrawDates has key {
    id: UID,
    first_semester_date: String,
    second_semester_date: String,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(SpecialNeedDao {
        id: object::new(ctx),
        min_approved_rate: 8_000, // 80%
        min_voters: 10,
    });

    transfer::share_object(BooksNeedWithdrawDates {
        id: object::new(ctx),
        first_semester_date: b"01/10".to_string(),
        second_semester_date: b"07/01".to_string(),
    });
}

public fun edit_special_need_dao_rate(
    _: &AdminCap,
    dao: &mut SpecialNeedDao,
    min_rate: u64,
    min_voters: u64,
) {
    if (min_rate > 0) {
        dao.min_approved_rate = min_rate;
    };

    if (min_voters > 0) {
        dao.min_voters = min_voters;
    };
}

public(package) fun init_books_need(semester: u64, year: u64, child: ID, ctx: &mut TxContext): ID {
    let need = BooksNeed {
        id: object::new(ctx),
        child: child,
        year: year,
        year_changes: vector[year],
        semester: semester,
        value: 0,
        donors: vector[],
        donations: vector[],
        withdraw_proposals: vector[],
        withdraws_for_need: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

/// Table ver
// public(package) fun init_meal_need(year: u64, ctx: &mut TxContext): ID {
//     let need = MealNeed {
//         id: object::new(ctx),
//         year: year,
//         value: 0,
//         donors: vector[],
//         donations: vector[],
//         durations: vector[],
//         total_supported_months: 0,
//         supported_years: table::new<u64, u64>(ctx),
//         withdraw_proposals: vector[],
//         withdraws_for_need: vector[],
//     };

//     let id = need.id.to_inner();
//     transfer::share_object(need);

//     id
// }

public(package) fun init_meal_need(year: u64, child: ID, ctx: &mut TxContext): ID {
    let need = MealNeed {
        id: object::new(ctx),
        child: child,
        year: year,
        value: 0,
        donors: vector[],
        donations: vector[],
        durations: vector[],
        total_supported_months: 0,
        supported_years: vec_map::empty<u64, u64>(),
        provide_meal_dates: vector[],
        provide_meal_periods: vector[],
        provide_meal_staffs: vector[],
        withdraw_proposals: vector[],
        withdraws_for_need: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun init_health_insurance_need(year: u64, child: ID, ctx: &mut TxContext): ID {
    let need = HealthInsuranceNeed {
        id: object::new(ctx),
        child: child,
        year: year,
        year_changes: vector[year],
        value: 0,
        donors: vector[],
        donations: vector[],
        withdraw_proposals: vector[],
        withdraws_for_need: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun confirm_provide_meal(
    need: &mut MealNeed,
    image_blob_id: String,
    provide_date: String,
    cur_time: u64,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&mut need.provide_meal_dates, &provide_date);
    assert!(!found, EChildProvidedMeal);

    vector::push_back(&mut need.provide_meal_dates, provide_date);
    vector::push_back(&mut need.provide_meal_periods, cur_time);
    vector::push_back(&mut need.provide_meal_staffs, ctx.sender());
}

public(package) fun confirm_provide_meal_v2(
    need: &mut MealNeed,
    image_blob_id: String,
    provide_date: String,
    actor: address,
    cur_time: u64,
) {
    let (found, _) = vector::index_of(&mut need.provide_meal_dates, &provide_date);
    assert!(!found, EChildProvidedMeal);

    vector::push_back(&mut need.provide_meal_dates, provide_date);
    vector::push_back(&mut need.provide_meal_periods, cur_time);
    vector::push_back(&mut need.provide_meal_staffs, actor);
}

public(package) fun support_books_need(
    need: &mut BooksNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
    amount: u64,
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
    let donor_id = process_suport_need(
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        ctx,
    );
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
    vector::push_back(&mut need.donors, donor_id);
}

public(package) fun support_health_insurance_need(
    need: &mut HealthInsuranceNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
    amount: u64,
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
    let donor_id = process_suport_need(
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        ctx,
    );
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
    vector::push_back(&mut need.donors, donor_id);
}

/// Table ver
// public(package) fun support_meal_need(
//     need: &mut MealNeed,
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     local_pool: &mut LocalPool,
//     donor: &mut DonorNFT,
//     months: u64,
//     start_period: String,
//     end_period: String,
//     first_name: String,
//     last_name: String,
//     gender: String,
//     phone_number: String,
//     email: String,
//     message: String,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     // let mut is_valid_support = months >= 1 && months <= 12;
//     assert!(months >= 1 && months <= 12, EInvalidSupportValue);
//     if (table::contains(&need.supported_years, need.year)) {
//         let supported_months = table::borrow_mut(&mut need.supported_years, need.year);
//         let total_months = *supported_months + months;
//         assert!(total_months <= 12, EInvalidSupportValue);
//         *supported_months = total_months;
//     } else {
//         table::add(&mut need.supported_years, need.year, months);
//     };

//     let amount = (months as u64) * need.value;
//     let donor_id = process_suport_need(
//         manage,
//         pool,
//         local_pool,
//         donor,
//         amount,
//         first_name,
//         last_name,
//         gender,
//         phone_number,
//         email,
//         message,
//         ctx,
//     );
//     vector::push_back(
//         &mut need.donations,
//         create_tx_record_v2(
//             amount,
//             b"VND".to_string(),
//             b"Support meal need".to_string(),
//             get_local_pool_region(local_pool),
//             message,
//             clock,
//             ctx,
//         ),
//     );
//     vector::push_back(&mut need.donors, donor_id);
//     vector::push_back(
//         &mut need.durations,
//         MealSupportDuration { start_period: start_period, end_period: end_period },
//     );
// }

public(package) fun support_meal_need(
    need: &mut MealNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
    amount: u64,
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
    // let mut is_valid_support = months >= 1 && months <= 12;
    let months = (amount / need.value as u64);
    assert!(months >= 1 && months <= 12, EInvalidSupportValue);
    if (vec_map::contains(&need.supported_years, &need.year)) {
        let supported_months = vec_map::get_mut(&mut need.supported_years, &need.year);
        let total_months = *supported_months + months;
        assert!(total_months <= 12, EInvalidSupportValue);
        *supported_months = total_months;
    } else {
        vec_map::insert(&mut need.supported_years, need.year, months);
    };

    let amount = (months as u64) * need.value;
    let donor_id = process_suport_need(
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        ctx,
    );
    vector::push_back(
        &mut need.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support meal need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
    vector::push_back(&mut need.donors, donor_id);
    vector::push_back(
        &mut need.durations,
        MealSupportDuration { start_period: start_period, end_period: end_period },
    );
}

public(package) fun create_special_need_proposal(
    child_id: ID,
    target: u64,
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

public(package) fun create_special_need_proposal_v2(
    child_id: ID,
    target: u64,
    description: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);
    assert!(target >= MIN_SPECIAL_NEED_TARGET, EInsufficientAmount);

    let proposal = SpecialNeedProposal {
        id: object::new(ctx),
        child: child_id,
        creator: creator,
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
    dao: &mut SpecialNeedDao,
    proposal: &mut SpecialNeedProposal,
    donor: &mut DonorNFT,
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
        proposal.approve_weight = proposal.approve_weight + get_donor_donate_amount(donor, ctx);
        vector::push_back(&mut proposal.approved_periods, cur_time);
    } else {
        vector::push_back(&mut proposal.refusers, sender);
        proposal.refuse_weight = proposal.refuse_weight + get_donor_donate_amount(donor, ctx);
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
    donor: &mut DonorNFT,
    amount: u64,
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
    process_suport_need(
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        ctx,
    );
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
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    process_withdraw_from_need(
        pool,
        local_pool,
        &campaign.withdraw_proposals,
        proposal,
        dao,
        clock,
        ctx,
    );

    campaign.withdraw_amount = campaign.withdraw_amount + get_withdraw_proposal_amount(proposal);
    let id = create_tx_record_v2(
        get_withdraw_proposal_amount(proposal),
        b"VND".to_string(),
        b"Withdraw".to_string(),
        get_local_pool_region(local_pool),
        get_withdraw_proposal_description(proposal),
        clock,
        ctx,
    );
    set_transaction_record_for_withdraw_proposal(proposal, id);
    vector::push_back(
        &mut campaign.withdraws,
        id,
    );
}

public(package) fun create_withdraw_proposal(
    campaign: &mut SpecialNeedCampaign,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let budget = campaign.total_donated - campaign.withdraw_amount;
    assert!(withdraw_amount <= budget, EInsufficientAmount);
    vector::push_back(
        &mut campaign.withdraw_proposals,
        create_withdraw_proposal_for_child_need(
            pool,
            local_pool,
            withdraw_amount,
            description,
            b"special".to_string(),
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_withdraw_proposal_v2(
    manage: &mut Manage,
    campaign: &mut SpecialNeedCampaign,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let budget = campaign.total_donated - campaign.withdraw_amount;
    assert!(withdraw_amount <= budget, EInsufficientAmount);
    vector::push_back(
        &mut campaign.withdraw_proposals,
        create_withdraw_proposal_for_child_need_v2(
            manage,
            pool,
            local_pool,
            withdraw_amount,
            description,
            b"special".to_string(),
            closed_at,
            creator,
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
        create_withdraw_proposal_for_child_need(
            pool,
            local_pool,
            need.value,
            description,
            b"books".to_string(),
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_books_need_withdraw_proposal_v2(
    manage: &mut Manage,
    need: &mut BooksNeed,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        vector::length(&need.donations) > vector::length(&need.withdraws_for_need),
        ENeedHasBeenFunded,
    );

    vector::push_back(
        &mut need.withdraw_proposals,
        create_withdraw_proposal_for_child_need_v2(
            manage,
            pool,
            local_pool,
            need.value,
            description,
            b"books".to_string(),
            closed_at,
            creator,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_health_insurance_need_withdraw_proposal(
    need: &mut HealthInsuranceNeed,
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
        create_withdraw_proposal_for_child_need(
            pool,
            local_pool,
            need.value,
            description,
            b"health".to_string(),
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_health_insurance_need_withdraw_proposal_v2(
    manage: &mut Manage,
    need: &mut HealthInsuranceNeed,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        vector::length(&need.donations) > vector::length(&need.withdraws_for_need),
        ENeedHasBeenFunded,
    );

    vector::push_back(
        &mut need.withdraw_proposals,
        create_withdraw_proposal_for_child_need_v2(
            manage,
            pool,
            local_pool,
            need.value,
            description,
            b"health".to_string(),
            closed_at,
            creator,
            clock,
            ctx,
        ),
    );
}

public(package) fun withdraw_from_books_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    process_withdraw_from_need(
        pool,
        local_pool,
        &need.withdraw_proposals,
        proposal,
        dao,
        clock,
        ctx,
    );

    let id = create_tx_record_v2(
        get_withdraw_proposal_amount(proposal),
        b"VND".to_string(),
        b"Withdraw".to_string(),
        get_local_pool_region(local_pool),
        get_withdraw_proposal_description(proposal),
        clock,
        ctx,
    );

    set_transaction_record_for_withdraw_proposal(proposal, id);
    vector::push_back(
        &mut need.withdraws_for_need,
        id,
    );
}

public(package) fun withdraw_from_health_insurance_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut HealthInsuranceNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    process_withdraw_from_need(
        pool,
        local_pool,
        &need.withdraw_proposals,
        proposal,
        dao,
        clock,
        ctx,
    );

    let id = create_tx_record_v2(
        get_withdraw_proposal_amount(proposal),
        b"VND".to_string(),
        b"Withdraw".to_string(),
        get_local_pool_region(local_pool),
        get_withdraw_proposal_description(proposal),
        clock,
        ctx,
    );

    set_transaction_record_for_withdraw_proposal(proposal, id);
    vector::push_back(
        &mut need.withdraws_for_need,
        id,
    );
}

public(package) fun create_meal_need_withdraw_proposal(
    need: &mut MealNeed,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        need.total_supported_months > vector::length(&need.withdraws_for_need),
        ENeedHasBeenFunded,
    );

    vector::push_back(
        &mut need.withdraw_proposals,
        create_withdraw_proposal_for_child_need(
            pool,
            local_pool,
            need.value,
            description,
            b"meal".to_string(),
            closed_at,
            clock,
            ctx,
        ),
    );
}

public(package) fun create_meal_need_withdraw_proposal_v2(
    manage: &mut Manage,
    need: &mut MealNeed,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        need.total_supported_months > vector::length(&need.withdraws_for_need),
        ENeedHasBeenFunded,
    );

    vector::push_back(
        &mut need.withdraw_proposals,
        create_withdraw_proposal_for_child_need_v2(
            manage,
            pool,
            local_pool,
            need.value,
            description,
            b"meal".to_string(),
            closed_at,
            creator,
            clock,
            ctx,
        ),
    );
}

public(package) fun withdraw_from_meal_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut MealNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    process_withdraw_from_need(
        pool,
        local_pool,
        &need.withdraw_proposals,
        proposal,
        dao,
        clock,
        ctx,
    );

    let id = create_tx_record_v2(
        get_withdraw_proposal_amount(proposal),
        b"VND".to_string(),
        b"Withdraw".to_string(),
        get_local_pool_region(local_pool),
        get_withdraw_proposal_description(proposal),
        clock,
        ctx,
    );
    set_transaction_record_for_withdraw_proposal(proposal, id);
    vector::push_back(
        &mut need.withdraws_for_need,
        id,
    );
}

public(package) fun get_books_need_id(need: &mut BooksNeed): ID {
    need.id.to_inner()
}

public(package) fun get_meal_need_id(need: &mut MealNeed): ID {
    need.id.to_inner()
}

public(package) fun get_health_insurance_need_id(need: &mut HealthInsuranceNeed): ID {
    need.id.to_inner()
}

public(package) fun calculate_aprroval_ratio(proposal: &mut SpecialNeedProposal): u64 {
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

fun process_suport_need(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
    amount: u64,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    ctx: &mut TxContext,
): ID {
    let donor_id = if (!is_donor_added(manage, ctx)) {
        mint_donor_nft_v2(
            manage,
            first_name,
            last_name,
            gender,
            phone_number,
            email,
            amount,
            ctx,
        )
    } else {
        update_donation_after_donate(donor, amount, ctx);
        get_donor_id(donor)
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    donor_id
}

fun process_withdraw_from_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    proposals: &vector<ID>,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        proposals,
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
}

// use sui::vec_map::{Self, VecMap};

// public struct MealNeed has key {
//     id: UID,
//     // ... các trường khác
//     supported_years: VecMap<u64, u64>,
// }

// let map = vec_map::empty<u64, u64>();

// /// Thêm một năm mới vào danh sách hỗ trợ
// public entry fun add_year(meal_need: &mut MealNeed, year: u64, months: u64) {
//     // Kiểm tra xem key đã tồn tại chưa để tránh lỗi abort
//     assert!(!vec_map::contains(&meal_need.supported_years, &year), 0);

//     vec_map::insert(&mut meal_need.supported_years, year, months);
// }

// /// Chỉnh sửa số tháng của một năm đã tồn tại
// public entry fun edit_year(meal_need: &mut MealNeed, year: u64, new_months: u64) {
//     // 1. Lấy tham chiếu có thể thay đổi (mutable reference) của giá trị dựa trên key
//     let value_mut = vec_map::get_mut(&mut meal_need.supported_years, &year);

//     // 2. Cập nhật giá trị mới
//     *value_mut = new_months;
// }

// /// Hàm "Upsert" (Nếu chưa có thì thêm, có rồi thì sửa)
// public entry fun upsert_year(meal_need: &mut MealNeed, year: u64, months: u64) {
//     if (vec_map::contains(&meal_need.supported_years, &year)) {
//         let value_mut = vec_map::get_mut(&mut meal_need.supported_years, &year);
//         *value_mut = months;
//     } else {
//         vec_map::insert(&mut meal_need.supported_years, year, months);
//     }
// }
