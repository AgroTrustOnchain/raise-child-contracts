module raise_child::pool;

use raise_child::manage::{
    Manage,
    add_sponsor_to_manage,
    is_sponsor_added,
    is_withdraw_requestor_valid
};
use raise_child::record::create_tx_record;
use raise_child::sponsor::{mint_sponsor_nft, SponsorNFT, get_sponsor_donate_amount};
use raise_child::vnd::VND;
use std::string::{Self, String};
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

public struct VndPool has key {
    id: UID,
    admin: address,
    balance: Balance<VND>,
    withdraw_proposals: vector<ID>,
    mods: vector<address>,
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
    closed_at: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(VndPool {
        id: object::new(ctx),
        admin: ctx.sender(),
        balance: balance::zero<VND>(),
        withdraw_proposals: vector[],
        mods: vector[],
        total_amount: 0,
    });

    transfer::share_object(PoolWithdrawDao {
        id: object::new(ctx),
        min_approved_rate: 8_000, // 80%
    });
}

public fun donate_to_pool(
    manage: &mut Manage,
    pool: &mut VndPool,
    treausury_cap: &mut TreasuryCap<VND>,
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

    let vnd = coin::mint(treausury_cap, (amount as u64), ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Donate".to_string();
    create_tx_record(amount, coin_type, action_type, message, clock, ctx);
}

public(package) fun create_local_pool(region: String, ctx: &mut TxContext) {
    transfer::share_object(LocalPool {
        id: object::new(ctx),
        region: region,
        mods: vector[ctx.sender()],
        total_amount: 0,
    })
}

// public fun withdraw_from_pool();
public fun withdraw_from_pool(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    proposal: &mut WithDrawProposal,
    treausury_cap: &mut TreasuryCap<VND>,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(proposal.closed_at < clock::timestamp_ms(clock), EWithdrawProposalStillPending);
    assert!(
        calculate_aprroval_ratio(proposal) >= dao.min_approved_rate,
        EProposalApproveRateNotPass,
    );
    assert!(!proposal.is_executed, EWithdrawProposalExecuted);

    if (proposal.is_from_local_pool) {
        assert!(proposal.pool_id == local_pool.id.to_inner(), ENotMatchedPoolInWithdraw);
        local_pool.total_amount = local_pool.total_amount - proposal.withdraw_amount;
    };

    proposal.is_executed = true;
    let withdraw_amount_u64 = (proposal.withdraw_amount as u64);
    let coin = coin::from_balance(balance::split(&mut pool.balance, withdraw_amount_u64), ctx);
    pool.total_amount = pool.total_amount - proposal.withdraw_amount;
    transfer::public_transfer(coin, proposal.creator);

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Withdraw".to_string();
    create_tx_record(
        proposal.withdraw_amount,
        coin_type,
        action_type,
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
    assert!(is_withdraw_requestor_valid(manage, ctx), EInvalidWithdrawRequester);
    assert!(closed_at > clock::timestamp_ms(clock), EPassPeriod);
    assert!(withdraw_amount > WITHDRAW_MIN_AMOUNT, EInsufficientAmount);
    assert!(withdraw_amount <= WITHDRAW_LIMIT_AMOUNT, EInsufficientAmount);

    let pool_id: ID;
    let pool_name: String;
    if (is_from_local_pool) {
        assert!(local_pool.total_amount >= withdraw_amount, EInsufficientAmount);
        pool_id = local_pool.id.to_inner();
        pool_name = local_pool.region;
    } else {
        assert!(pool.total_amount >= withdraw_amount, EInsufficientAmount);
        pool_id = pool.id.to_inner();
        pool_name = b"Main Pool".to_string();
    };

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
        proposal.approve_weight = proposal.approve_weight + get_sponsor_donate_amount(sponsor);
    } else {
        vector::push_back(&mut proposal.refusers, sender);
        proposal.refuse_weight = proposal.refuse_weight + get_sponsor_donate_amount(sponsor);
        vector::push_back(&mut proposal.refuse_reasons, refuse_reason);
    };
}

fun calculate_aprroval_ratio(proposal: &mut WithDrawProposal): u128 {
    let total = proposal.approve_weight + proposal.refuse_weight;
    if (total == 0) return 0;

    (proposal.approve_weight * PRESISION_FACTOR) / total
}
