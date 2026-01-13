module raise_child::pool;

use raise_child::manage::{Manage, add_sponsor_to_manage, is_sponsor_added};
use raise_child::record::create_tx_record;
use raise_child::sponsor::mint_sponsor_nft;
use raise_child::vnd::VND;
use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, TreasuryCap};

const ENotAuthorized: u64 = 1;
const EZeroAmount: u64 = 2;
const EInsufficientAmount: u64 = 3;
const ENegativeAmount: u64 = 4;

public struct VndPool has key {
    id: UID,
    admin: address,
    balance: Balance<VND>,
    mods: vector<address>,
    total_amount: u64,
}

fun init(ctx: &mut TxContext) {
    let pool = VndPool {
        id: object::new(ctx),
        admin: ctx.sender(),
        balance: balance::zero<VND>(),
        mods: vector[],
        total_amount: 0,
    };

    transfer::share_object(pool);
}

public fun donate_to_pool(
    manage: &mut Manage,
    pool: &mut VndPool,
    treausury_cap: &mut TreasuryCap<VND>,
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

    if (!is_sponsor_added(manage, ctx)) {
        mint_sponsor_nft(manage, first_name, last_name, gender, phone_number, email, ctx);
        add_sponsor_to_manage(manage, ctx);
    };

    let vnd = coin::mint(treausury_cap, amount, ctx);
    balance::join(&mut pool.balance, coin::into_balance(vnd));
    pool.total_amount = pool.total_amount + amount;

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Donate".to_string();
    create_tx_record(amount, coin_type, action_type, message, clock, ctx);
}

// public fun withdraw_from_pool();
public fun withdraw_from_pool(
    pool: &mut VndPool,
    treausury_cap: &mut TreasuryCap<VND>,
    amount: u64,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(amount > 0, ENegativeAmount);
    assert!(pool.total_amount < amount, EInsufficientAmount);

    let (found, _) = vector::index_of(&mut pool.mods, &ctx.sender());
    assert!(found, ENotAuthorized);

    let coin = coin::from_balance(balance::split(&mut pool.balance, amount), ctx);
    pool.total_amount = pool.total_amount - amount;

    transfer::public_transfer(coin, ctx.sender());

    let coin_type: String = b"VND".to_string();
    let action_type: String = b"Withdraw".to_string();
    create_tx_record(amount, coin_type, action_type, message, clock, ctx);
}
