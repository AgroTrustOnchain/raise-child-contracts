module raise_child::pool;

use raise_child::donor::{
    mint_donor_nft,
    DonorNFT,
    get_donor_donate_amount,
    update_donation_after_donate
};
use raise_child::manage::{
    Manage,
    AdminCap,
    add_donor_to_manage,
    is_donor_added,
    is_admin_added,
    is_admin_added_v2,
    is_withdraw_requestor_valid
};
use raise_child::record::{create_tx_record, create_tx_record_v2};
use raise_child::vnd::VND;
use std::address::length;
use std::ascii::index_of;
use std::option::{Self, Option};
use std::string::{Self, String};
use std::vector::push_back;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, TreasuryCap};
use sui::event::{Self, emit};
use sui::transfer::share_object;

const ENotAuthorized: u64 = 1;
const EZeroAmount: u64 = 2;
const EInsufficientAmount: u64 = 3;
const ENegativeAmount: u64 = 4;
const EPassPeriod: u64 = 5;
const EInvalidWithdrawRequester: u64 = 6;
const EWithdrawProposalExecuted: u64 = 7;
const EProposalOwnerVote: u64 = 8;
const EAlreadyVoteProposal: u64 = 9;
const EWithdrawProposalStillPending: u64 = 10;
const EProposalApproveRateNotPass: u64 = 11;
const ENotMatchedPoolInWithdraw: u64 = 12;
const ENotEnoughVoters: u64 = 13;

const WITHDRAW_MIN_AMOUNT: u64 = 2_000;
const WITHDRAW_LIMIT_AMOUNT: u64 = 20_000_000;
const PRESISION_FACTOR: u64 = 1_000;

// public struct VndPool has key {
//     id: UID,
//     admin: address,
//     balance: Balance<VND>,
//     local_pools: vector<ID>,
//     withdraw_proposals: vector<ID>,
//     total_amount: u64,
// }

public struct VndPool has key {
    id: UID,
    treasury_cap: TreasuryCap<VND>,
    balance: Balance<VND>,
    local_pools: vector<ID>,
    withdraw_proposals: vector<ID>,
    total_amount: u64,
    total_meal_donation_amount: u64,
    total_books_donation_amount: u64,
    total_health_insurance_donation_amount: u64,
}

public struct LocalPool has key {
    id: UID,
    region: String,
    mods: vector<address>,
    total_amount: u64,
    total_meal_donation_amount: u64,
    total_books_donation_amount: u64,
    total_health_insurance_donation_amount: u64,
}

public struct PoolWithdrawDao has key {
    id: UID,
    min_approved_rate: u64,
    min_voters: u64,
}

public struct WithdrawProposal has key {
    id: UID,
    pool_id: ID,
    pool_name: String,
    creator: address,
    withdraw_amount: u64,
    description: String,
    approvers: vector<address>,
    refusers: vector<address>,
    approve_weight: u64,
    refuse_weight: u64,
    refuse_reasons: vector<String>,
    is_executed: bool,
    is_from_local_pool: bool,
    purpose: String,
    approved_periods: vector<u64>,
    refused_periods: vector<u64>,
    transaction_record_id: Option<ID>,
    created_at: u64,
    updated_at: u64,
    closed_at: u64,
}

public struct WithdrawProposalCreated has copy, drop {
    id: ID,
}

fun init(ctx: &mut TxContext) {
    // transfer::share_object(VndPool {
    //     id: object::new(ctx),
    //     admin: ctx.sender(),
    //     balance: balance::zero<VND>(),
    //     local_pools: vector[],
    //     withdraw_proposals: vector[],
    //     total_amount: 0,
    // });

    // transfer::share_object(VndPool {
    //     id: object::new(ctx),
    //     balance: balance::zero<VND>(),
    //     local_pools: vector[],
    //     withdraw_proposals: vector[],
    //     total_amount: 0,
    // });

    transfer::share_object(LocalPool {
        id: object::new(ctx),
        region: b"".to_string(),
        mods: vector[],
        total_amount: 0,
        total_meal_donation_amount: 0,
        total_books_donation_amount: 0,
        total_health_insurance_donation_amount: 0,
    });

    transfer::share_object(PoolWithdrawDao {
        id: object::new(ctx),
        min_approved_rate: 8_000, // 80%
        min_voters: 10,
    });
}

public entry fun init_pool(cap: TreasuryCap<VND>, ctx: &mut TxContext) {
    transfer::share_object(VndPool {
        id: object::new(ctx),
        treasury_cap: cap,
        balance: balance::zero<VND>(),
        local_pools: vector[],
        withdraw_proposals: vector[],
        total_amount: 0,
        total_meal_donation_amount: 0,
        total_books_donation_amount: 0,
        total_health_insurance_donation_amount: 0,
    });
}

public fun edit_withdraw_dao_rate(
    _: &AdminCap,
    dao: &mut PoolWithdrawDao,
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

// public fun donate_to_pool(
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     treausury_cap: &mut TreasuryCap<VND>,
//     donor: &mut DonorNFT,
//     amount: u64,
//     first_name: String,
//     last_name: String,
//     gender: String,
//     phone_number: String,
//     email: String,
//     message: String,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     assert!(amount > 0, ENegativeAmount);

//     if (!is_donor_added(manage, ctx)) {
//         mint_donor_nft(
//             manage,
//             first_name,
//             last_name,
//             gender,
//             phone_number,
//             email,
//             amount,
//             ctx,
//         );
//         add_donor_to_manage(manage, ctx);
//     };

//     let vnd = coin::mint(treausury_cap, (amount as u64), ctx);
//     update_donation_after_donate(donor, amount, ctx);
//     balance::join(&mut pool.balance, coin::into_balance(vnd));
//     pool.total_amount = pool.total_amount + amount;

//     let coin_type: String = b"VND".to_string();
//     let action_type: String = b"Donate".to_string();
//     create_tx_record(amount, coin_type, action_type, b"Main Pool".to_string(), message, clock, ctx);
// }

public fun donate_to_pool(
    manage: &mut Manage,
    pool: &mut VndPool,
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
    assert!(amount > 0, ENegativeAmount);

    if (!is_donor_added(manage, ctx)) {
        mint_donor_nft(
            manage,
            first_name,
            last_name,
            gender,
            phone_number,
            email,
            amount,
            ctx,
        );
        add_donor_to_manage(manage, ctx);
    };

    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    update_donation_after_donate(donor, amount, ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Donate".to_string();
    create_tx_record(amount, coin_type, action_type, b"Main Pool".to_string(), message, clock, ctx);
}

// public fun donate_to_local_pool(
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     local_pool: &mut LocalPool,
//     treausury_cap: &mut TreasuryCap<VND>,
//     donor: &mut DonorNFT,
//     amount: u64,
//     first_name: String,
//     last_name: String,
//     gender: String,
//     phone_number: String,
//     email: String,
//     message: String,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     assert!(amount > 0, ENegativeAmount);

//     if (!is_donor_added(manage, ctx)) {
//         mint_donor_nft(
//             manage,
//             first_name,
//             last_name,
//             gender,
//             phone_number,
//             email,
//             amount,
//             ctx,
//         );
//         add_donor_to_manage(manage, ctx);
//     } else {
//         update_donation_after_donate(donor, amount, ctx);
//     };

//     let vnd = coin::mint(treausury_cap, (amount as u64), ctx);
//     balance::join(&mut pool.balance, coin::into_balance(vnd));
//     pool.total_amount = pool.total_amount + amount;
//     local_pool.total_amount = local_pool.total_amount + amount;

//     let coin_type: String = b"VND".to_string();
//     let action_type: String = b"Donate".to_string();
//     create_tx_record(amount, coin_type, action_type, local_pool.region, message, clock, ctx);
// }

public fun donate_to_local_pool(
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
    assert!(amount > 0, ENegativeAmount);

    if (!is_donor_added(manage, ctx)) {
        mint_donor_nft(
            manage,
            first_name,
            last_name,
            gender,
            phone_number,
            email,
            amount,
            ctx,
        );
        add_donor_to_manage(manage, ctx);
    } else {
        update_donation_after_donate(donor, amount, ctx);
    };

    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;
    local_pool.total_amount = local_pool.total_amount + amount;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Donate".to_string();
    create_tx_record(amount, coin_type, action_type, local_pool.region, message, clock, ctx);
}

public(package) fun mint_vnd(pool: &mut VndPool, amount: u64, ctx: &mut TxContext) {
    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;
}

public(package) fun split_vnd(
    pool: &mut VndPool,
    proposal: &mut WithdrawProposal,
    ctx: &mut TxContext,
) {
    let withdraw_amount_u64 = (proposal.withdraw_amount as u64);
    let coin = coin::from_balance(balance::split(&mut pool.balance, withdraw_amount_u64), ctx);
    pool.total_amount = pool.total_amount - proposal.withdraw_amount;
    transfer::public_transfer(coin, proposal.creator);
}

public(package) fun set_transaction_record_for_withdraw_proposal(
    proposal: &mut WithdrawProposal,
    id: ID,
) {
    proposal.transaction_record_id = option::some(id);
}

public(package) fun create_local_pool(
    pool: &mut VndPool,
    region: String,
    leaders: vector<address>,
    ctx: &mut TxContext,
) {
    let local_pool = LocalPool {
        id: object::new(ctx),
        region: region,
        mods: leaders,
        total_amount: 0,
        total_meal_donation_amount: 0,
        total_books_donation_amount: 0,
        total_health_insurance_donation_amount: 0,
    };

    vector::push_back(&mut pool.local_pools, local_pool.id.to_inner());
    transfer::share_object(local_pool);
}

// public fun withdraw_from_pool(
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     local_pool: &mut LocalPool,
//     proposal: &mut WithdrawProposal,
//     treausury_cap: &mut TreasuryCap<VND>,
//     dao: &mut PoolWithdrawDao,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     let cur_time = clock::timestamp_ms(clock);
//     assert!(proposal.closed_at <= cur_time, EWithdrawProposalStillPending);
//     assert!(
//         calculate_aprroval_ratio(proposal) >= dao.min_approved_rate,
//         EProposalApproveRateNotPass,
//     );
//     assert!(!proposal.is_executed, EWithdrawProposalExecuted);

//     let pool_name: String;
//     if (proposal.is_from_local_pool) {
//         assert!(proposal.pool_id == local_pool.id.to_inner(), ENotMatchedPoolInWithdraw);
//         local_pool.total_amount = local_pool.total_amount - proposal.withdraw_amount;
//         pool_name = local_pool.region;
//     } else {
//         pool_name = b"Main Pool".to_string();
//     };

//     let withdraw_amount_u64 = (proposal.withdraw_amount as u64);
//     let coin = coin::from_balance(balance::split(&mut pool.balance, withdraw_amount_u64), ctx);
//     pool.total_amount = pool.total_amount - proposal.withdraw_amount;
//     transfer::public_transfer(coin, proposal.creator);
//     proposal.is_executed = true;
//     proposal.updated_at = cur_time;

//     let coin_type: String = b"VND".to_string();
//     let action_type: String = b"Withdraw".to_string();
//     create_tx_record(
//         proposal.withdraw_amount,
//         coin_type,
//         action_type,
//         pool_name,
//         proposal.description,
//         clock,
//         ctx,
//     );
// }

public fun withdraw_from_pool(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    _: &AdminCap,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(proposal.closed_at <= cur_time, EWithdrawProposalStillPending);
    assert!(
        calculate_withdraw_aprroval_ratio(proposal) >= dao.min_approved_rate,
        EProposalApproveRateNotPass,
    );
    assert!(
        vector::length(&proposal.approvers) + vector::length(&proposal.refusers) >= dao.min_voters,
        ENotEnoughVoters,
    );
    assert!(!proposal.is_executed, EWithdrawProposalExecuted);

    let pool_name: String;
    if (proposal.is_from_local_pool) {
        assert!(proposal.pool_id == local_pool.id.to_inner(), ENotMatchedPoolInWithdraw);
        local_pool.total_amount = local_pool.total_amount - proposal.withdraw_amount;
        pool_name = local_pool.region;
    } else {
        assert!(proposal.pool_id == pool.id.to_inner(), ENotMatchedPoolInWithdraw);
        pool_name = b"Main Pool".to_string();
    };

    let withdraw_amount_u64 = (proposal.withdraw_amount as u64);
    let coin = coin::from_balance(balance::split(&mut pool.balance, withdraw_amount_u64), ctx);
    pool.total_amount = pool.total_amount - proposal.withdraw_amount;
    transfer::public_transfer(coin, proposal.creator);
    proposal.is_executed = true;
    proposal.updated_at = cur_time;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Withdraw".to_string();
    let id = create_tx_record_v2(
        proposal.withdraw_amount,
        coin_type,
        action_type,
        pool_name,
        proposal.description,
        clock,
        ctx,
    );

    proposal.transaction_record_id = option::some(id);
}

public fun create_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    is_from_local_pool: bool,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let amount: u64;
    let pool_id: ID;
    let pool_name: String;
    let mut is_authorized = is_admin_added(manage, ctx);
    if (is_from_local_pool) {
        let (leader_found, _) = vector::index_of(&mut local_pool.mods, &ctx.sender());
        is_authorized = is_authorized || leader_found;
        amount = pool.total_amount;
        pool_id = local_pool.id.to_inner();
        pool_name = local_pool.region;
    } else {
        amount = local_pool.total_amount;
        pool_id = pool.id.to_inner();
        pool_name = b"Main Pool".to_string();
    };
    assert!(is_authorized, ENotAuthorized);

    let is_valid_amount =
        withdraw_amount >= WITHDRAW_MIN_AMOUNT && withdraw_amount <= WITHDRAW_LIMIT_AMOUNT && withdraw_amount <= amount;
    assert!(is_valid_amount, EInsufficientAmount);

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: pool_id,
        pool_name: pool_name,
        creator: ctx.sender(),
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: is_from_local_pool,
        purpose: b"Other".to_string(),
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();

    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    event::emit(WithdrawProposalCreated { id });
}

// Admin approve pending proposal to publish it on chain
public fun create_withdraw_proposal_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    is_from_local_pool: bool,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    assert!(
        is_leader_in_pool_v2(local_pool, creator) || is_admin_added_v2(manage, creator),
        ENotAuthorized,
    );
    assert!(is_admin_added(manage, ctx) && ctx.sender() != creator, ENotAuthorized);

    let amount: u64;
    let pool_id: ID;
    let pool_name: String;
    if (is_from_local_pool) {
        amount = pool.total_amount;
        pool_id = local_pool.id.to_inner();
        pool_name = local_pool.region;
    } else {
        amount = local_pool.total_amount;
        pool_id = pool.id.to_inner();
        pool_name = b"Main Pool".to_string();
    };

    let is_valid_amount =
        withdraw_amount >= WITHDRAW_MIN_AMOUNT && withdraw_amount <= WITHDRAW_LIMIT_AMOUNT && withdraw_amount <= amount;
    assert!(is_valid_amount, EInsufficientAmount);

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: pool_id,
        pool_name: pool_name,
        creator: creator,
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: is_from_local_pool,
        purpose: b"Other".to_string(),
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();

    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    event::emit(WithdrawProposalCreated { id });
}

public(package) fun create_withdraw_proposal_for_child_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    need_type: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let purpose = if (need_type == b"books".to_string()) {
        b"Child Books Need".to_string()
    } else if (need_type == b"meal".to_string()) {
        b"Child Meal Need".to_string()
    } else if (need_type == b"special".to_string()) {
        b"Child Special Need".to_string()
    } else {
        b"Child Health Insurance Need".to_string()
    };

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: local_pool.id.to_inner(),
        pool_name: local_pool.region,
        creator: ctx.sender(),
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: true,
        purpose: purpose,
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    event::emit(WithdrawProposalCreated { id });
    id
}

public(package) fun create_withdraw_proposal_for_child_need_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    need_type: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    //let (leader_found, _) = vector::index_of(&mut local_pool.mods, &creator);
    assert!(
        is_leader_in_pool_v2(local_pool, creator) || is_admin_added_v2(manage, creator),
        ENotAuthorized,
    );

    assert!(is_admin_added(manage, ctx) && ctx.sender() != creator, ENotAuthorized);

    let purpose = if (need_type == b"books".to_string()) {
        b"Child Books Need".to_string()
    } else if (need_type == b"meal".to_string()) {
        b"Child Meal Need".to_string()
    } else if (need_type == b"special".to_string()) {
        b"Child Special Need".to_string()
    } else {
        b"Child Health Insurance Need".to_string()
    };

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: local_pool.id.to_inner(),
        pool_name: local_pool.region,
        creator: creator,
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: true,
        purpose: purpose,
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    event::emit(WithdrawProposalCreated { id });
    id
}

public(package) fun create_withdraw_proposal_for_special_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: local_pool.id.to_inner(),
        pool_name: local_pool.region,
        creator: ctx.sender(),
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: true,
        purpose: b"Child Special Need".to_string(),
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    event::emit(WithdrawProposalCreated { id });
    id
}

public(package) fun create_withdraw_proposal_for_books_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: local_pool.id.to_inner(),
        pool_name: local_pool.region,
        creator: ctx.sender(),
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: true,
        purpose: b"Child Books Need".to_string(),
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    id
}

public(package) fun create_withdraw_proposal_for_meal_need(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let proposal = WithdrawProposal {
        id: object::new(ctx),
        pool_id: local_pool.id.to_inner(),
        pool_name: local_pool.region,
        creator: ctx.sender(),
        withdraw_amount: withdraw_amount,
        description: description,
        approvers: vector[],
        refusers: vector[],
        refuse_reasons: vector[],
        approve_weight: 0,
        refuse_weight: 0,
        is_executed: false,
        is_from_local_pool: true,
        purpose: b"Child Meal Need".to_string(),
        approved_periods: vector[],
        refused_periods: vector[],
        transaction_record_id: option::none(),
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    let id = proposal.id.to_inner();
    vector::push_back(&mut pool.withdraw_proposals, id);
    transfer::share_object(proposal);
    id
}

public fun vote_withdraw_proposal(
    proposal: &mut WithdrawProposal,
    donor: &mut DonorNFT,
    dao: &mut PoolWithdrawDao,
    is_approve: bool,
    refuse_reason: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(!proposal.is_executed, EWithdrawProposalExecuted);
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

public(package) fun calculate_withdraw_aprroval_ratio(proposal: &mut WithdrawProposal): u64 {
    let total = proposal.approve_weight + proposal.refuse_weight;
    if (total == 0) return 0;

    (proposal.approve_weight * PRESISION_FACTOR) / total
}

public(package) fun add_leader_to_pool(pool: &mut LocalPool, ctx: &mut TxContext) {
    vector::push_back(&mut pool.mods, ctx.sender());
}

public(package) fun get_local_pool_region(pool: &mut LocalPool): String {
    pool.region
}

public(package) fun add_amount_to_local_pool(pool: &mut LocalPool, amount: u64) {
    pool.total_amount = pool.total_amount + amount;
}

public(package) fun is_leader_in_pool(pool: &mut LocalPool, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut pool.mods, &ctx.sender());
    found
}

public(package) fun is_leader_in_pool_v2(pool: &mut LocalPool, sender: address): bool {
    let (found, _) = vector::index_of(&mut pool.mods, &sender);
    found
}

public(package) fun get_withdraw_proposal_close_period(proposal: &mut WithdrawProposal): u64 {
    proposal.closed_at
}

public(package) fun get_withdraw_dao_min_approve_rate(dao: &mut PoolWithdrawDao): u64 {
    dao.min_approved_rate
}

public(package) fun get_withdraw_dao_min_voters(dao: &mut PoolWithdrawDao): u64 {
    dao.min_voters
}

public(package) fun get_withdraw_proposal_execute_status(proposal: &mut WithdrawProposal): bool {
    proposal.is_executed
}

public(package) fun get_withdraw_proposal_approvers_number(proposal: &mut WithdrawProposal): u64 {
    vector::length(&proposal.approvers)
}

public(package) fun get_withdraw_proposal_refusers_number(proposal: &mut WithdrawProposal): u64 {
    vector::length(&proposal.refusers)
}

public(package) fun set_withdraw_proposal_executed(proposal: &mut WithdrawProposal, cur_time: u64) {
    proposal.is_executed = true;
    proposal.updated_at = cur_time;
}

public(package) fun get_withdraw_proposal_amount(proposal: &mut WithdrawProposal): u64 {
    proposal.withdraw_amount
}

public(package) fun get_withdraw_proposal_description(proposal: &mut WithdrawProposal): String {
    proposal.description
}

public(package) fun get_withdraw_proposal_id(proposal: &mut WithdrawProposal): ID {
    proposal.id.to_inner()
}

public(package) fun is_withdraw_proposal_matched_local_pool(
    proposal: &mut WithdrawProposal,
    pool: &mut LocalPool,
): bool {
    proposal.pool_name == pool.region
}

public(package) fun add_donation_amount_to_specific_need_in_pool(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need_type: String,
    amount: u64,
) {
    if (need_type == b"books".to_string()) {
        pool.total_books_donation_amount = pool.total_books_donation_amount + amount;
    } else if (need_type == b"meal".to_string()) {
        pool.total_meal_donation_amount = pool.total_meal_donation_amount + amount;
    } else if (need_type == b"health".to_string()) {
        pool.total_health_insurance_donation_amount =
            pool.total_health_insurance_donation_amount + amount;
    };
}
