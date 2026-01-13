module raise_child::manage;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::transfer::{Self, public_transfer};

const ENotAuthorized: u64 = 1;
const EZeroAmount: u64 = 2;
const EInsufficientAmount: u64 = 3;
const ESponsorExisted: u64 = 4;

public struct Manage has key {
    id: UID,
    admin: address,
    child_ids: vector<ID>,
    volunteer_ids: vector<ID>,
    local_leader_ids: vector<ID>,
    sponsor_ids: vector<address>,
}

// public struct SuiPool has key {
//     id: UID,
//     admin: address,
//     balance: Balance<SUI>,
//     total_amount: u64,
// }

fun init(ctx: &mut TxContext) {
    let sender = ctx.sender();

    // let sui_pool = SuiPool {
    //     id: object::new(ctx),
    //     admin: sender,
    //     balance: balance::zero<SUI>(),
    //     total_amount: 0,
    // };

    let manage = Manage {
        id: object::new(ctx),
        admin: sender,
        child_ids: vector[],
        volunteer_ids: vector[],
        local_leader_ids: vector[],
        sponsor_ids: vector[],
    };

    transfer::share_object(manage);
}

public fun is_sponsor_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.sponsor_ids, &ctx.sender());
    found
}

public fun add_sponsor_to_manage(manage: &mut Manage, ctx: &mut TxContext) {
    assert!(!is_sponsor_added(manage, ctx), ESponsorExisted);
    vector::push_back(&mut manage.sponsor_ids, ctx.sender());
}

public fun add_child_to_manage(manage: &mut Manage, id: ID, ctx: &mut TxContext) {
    vector::push_back(&mut manage.child_ids, id);
}

public fun add_volunteer_to_manage(manage: &mut Manage, id: ID, ctx: &mut TxContext) {
    vector::push_back(&mut manage.volunteer_ids, id);
}

public fun add_local_leader_to_manage(manage: &mut Manage, id: ID, ctx: &mut TxContext) {
    vector::push_back(&mut manage.local_leader_ids, id);
}
