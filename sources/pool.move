module raise_child::pool;

use raise_child::manage::{
    Manage,
    AdminCap,
    add_sponsor_to_manage,
    is_sponsor_added,
    is_admin_added,
    is_withdraw_requestor_valid
};
use raise_child::record::create_tx_record;
use raise_child::sponsor::{
    mint_sponsor_nft,
    SponsorNFT,
    get_sponsor_donate_amount,
    update_donation_after_donate
};
use raise_child::vnd::VND;
use std::ascii::index_of;
use std::string::{Self, String};
use std::vector::push_back;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, TreasuryCap};
use sui::tx_context::TxContext;

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

const WITHDRAW_MIN_AMOUNT: u128 = 2_000;
const WITHDRAW_LIMIT_AMOUNT: u128 = 20_000_000;
const PRESISION_FACTOR: u128 = 1_000;

// public struct VndPool has key {
//     id: UID,
//     admin: address,
//     balance: Balance<VND>,
//     local_pools: vector<ID>,
//     withdraw_proposals: vector<ID>,
//     total_amount: u128,
// }

public struct VndPool has key {
    id: UID,
    treasury_cap: TreasuryCap<VND>,
    balance: Balance<VND>,
    local_pools: vector<ID>,
    withdraw_proposals: vector<ID>,
    total_amount: u128,
}

public struct LocalPool has key {
    id: UID,
    region: String,
    mods: vector<address>,
    total_amount: u128,
}

public struct PoolWithdrawDao has key {
    id: UID,
    min_approved_rate: u128,
}

public struct WithDrawProposal has key {
    id: UID,
    pool_id: ID,
    pool_name: String,
    creator: address,
    withdraw_amount: u128,
    description: String,
    approvers: vector<address>,
    refusers: vector<address>,
    approve_weight: u128,
    refuse_weight: u128,
    refuse_reasons: vector<String>,
    is_executed: bool,
    is_from_local_pool: bool,
    approved_periods: vector<u64>,
    refused_periods: vector<u64>,
    created_at: u64,
    updated_at: u64,
    closed_at: u64,
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

    transfer::share_object(PoolWithdrawDao {
        id: object::new(ctx),
        min_approved_rate: 8_000, // 80%
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
    });
}

// public fun donate_to_pool(
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     treausury_cap: &mut TreasuryCap<VND>,
//     sponsor: &mut SponsorNFT,
//     amount: u128,
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

//     if (!is_sponsor_added(manage, ctx)) {
//         mint_sponsor_nft(
//             manage,
//             first_name,
//             last_name,
//             gender,
//             phone_number,
//             email,
//             amount,
//             ctx,
//         );
//         add_sponsor_to_manage(manage, ctx);
//     };

//     let vnd = coin::mint(treausury_cap, (amount as u64), ctx);
//     update_donation_after_donate(sponsor, amount, ctx);
//     balance::join(&mut pool.balance, coin::into_balance(vnd));
//     pool.total_amount = pool.total_amount + amount;

//     let coin_type: String = b"VND".to_string();
//     let action_type: String = b"Donate".to_string();
//     create_tx_record(amount, coin_type, action_type, b"Main Pool".to_string(), message, clock, ctx);
// }

public fun donate_to_pool(
    manage: &mut Manage,
    pool: &mut VndPool,
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
    assert!(amount > 0, ENegativeAmount);

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
        add_sponsor_to_manage(manage, ctx);
    };

    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    update_donation_after_donate(sponsor, amount, ctx);
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
//     sponsor: &mut SponsorNFT,
//     amount: u128,
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

//     if (!is_sponsor_added(manage, ctx)) {
//         mint_sponsor_nft(
//             manage,
//             first_name,
//             last_name,
//             gender,
//             phone_number,
//             email,
//             amount,
//             ctx,
//         );
//         add_sponsor_to_manage(manage, ctx);
//     } else {
//         update_donation_after_donate(sponsor, amount, ctx);
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
    assert!(amount > 0, ENegativeAmount);

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
        add_sponsor_to_manage(manage, ctx);
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
    };

    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;
    local_pool.total_amount = local_pool.total_amount + amount;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Donate".to_string();
    create_tx_record(amount, coin_type, action_type, local_pool.region, message, clock, ctx);
}

public(package) fun mint_vnd(pool: &mut VndPool, amount: u128, ctx: &mut TxContext) {
    let vnd = coin::mint(&mut pool.treasury_cap, (amount as u64), ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;
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
    };

    vector::push_back(&mut pool.local_pools, local_pool.id.to_inner());
    transfer::share_object(local_pool);
}

// public fun withdraw_from_pool(
//     manage: &mut Manage,
//     pool: &mut VndPool,
//     local_pool: &mut LocalPool,
//     proposal: &mut WithDrawProposal,
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
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(proposal.closed_at <= cur_time, EWithdrawProposalStillPending);
    assert!(
        calculate_aprroval_ratio(proposal) >= dao.min_approved_rate,
        EProposalApproveRateNotPass,
    );
    assert!(!proposal.is_executed, EWithdrawProposalExecuted);

    let pool_name: String;
    if (proposal.is_from_local_pool) {
        assert!(proposal.pool_id == local_pool.id.to_inner(), ENotMatchedPoolInWithdraw);
        local_pool.total_amount = local_pool.total_amount - proposal.withdraw_amount;
        pool_name = local_pool.region;
    } else {
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
    create_tx_record(
        proposal.withdraw_amount,
        coin_type,
        action_type,
        pool_name,
        proposal.description,
        clock,
        ctx,
    );
}

public fun create_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    withdraw_amount: u128,
    description: String,
    is_from_local_pool: bool,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let cur_time = clock::timestamp_ms(clock);
    assert!(closed_at > cur_time, EPassPeriod);

    let amount: u128;
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

    let proposal = WithDrawProposal {
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
        approved_periods: vector[],
        refused_periods: vector[],
        created_at: cur_time,
        updated_at: cur_time,
        closed_at: closed_at,
    };

    vector::push_back(&mut pool.withdraw_proposals, proposal.id.to_inner());
    transfer::share_object(proposal);
}

public fun vote_withdraw_proposal(
    proposal: &mut WithDrawProposal,
    sponsor: &mut SponsorNFT,
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

fun calculate_aprroval_ratio(proposal: &mut WithDrawProposal): u128 {
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

public(package) fun add_amount_to_local_pool(pool: &mut LocalPool, amount: u128) {
    pool.total_amount = pool.total_amount + amount;
}
