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
const ELeaderExisted: u64 = 5;
const ERegionExisted: u64 = 6;
const EVolunteerExisted: u64 = 7;

public struct Manage has key {
    id: UID,
    admin: address,
    child_ids: vector<ID>,
    volunteer_nfts: vector<ID>,
    volunteer_ids: vector<address>,
    local_leader_nfts: vector<ID>,
    local_leader_ids: vector<address>,
    local_regions: vector<String>,
    sponsor_nfts: vector<ID>,
    sponsor_ids: vector<address>,
}

fun init(ctx: &mut TxContext) {
    let manage = Manage {
        id: object::new(ctx),
        admin: ctx.sender(),
        child_ids: vector[],
        volunteer_nfts: vector[],
        volunteer_ids: vector[],
        local_leader_nfts: vector[],
        local_leader_ids: vector[],
        local_regions: vector[],
        sponsor_nfts: vector[],
        sponsor_ids: vector[],
    };

    transfer::share_object(manage);
}

public(package) fun is_withdraw_requestor_valid(manage: &mut Manage, ctx: &mut TxContext): bool {
    ctx.sender() == manage.admin || is_sponsor_added(manage, ctx) || is_leader_added(manage, ctx) || is_volunteer_added(manage, ctx)
}

public(package) fun is_sponsor_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.sponsor_ids, &ctx.sender());
    found
}

public(package) fun is_volunteer_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.volunteer_ids, &ctx.sender());
    found
}

public(package) fun is_leader_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.local_leader_ids, &ctx.sender());
    found
}

public(package) fun is_local_region_added(manage: &mut Manage, region: String): bool {
    let (found, _) = vector::index_of(&mut manage.local_regions, &region);
    found
}

// public(package) fun is_admin_existed(manage: &mut Manage, ctx: &mut TxContext): bool {
//     manage.admin == ctx.sender()
// }

public(package) fun add_sponsor_to_manage(manage: &mut Manage, ctx: &mut TxContext) {
    assert!(!is_sponsor_added(manage, ctx), ESponsorExisted);
    vector::push_back(&mut manage.sponsor_ids, ctx.sender());
}

public(package) fun add_child_to_manage(manage: &mut Manage, id: ID, ctx: &mut TxContext) {
    vector::push_back(&mut manage.child_ids, id);
}

public(package) fun add_volunteer_to_manage(manage: &mut Manage, id: ID, ctx: &mut TxContext) {
    assert!(!is_volunteer_added(manage, ctx), EVolunteerExisted);
    vector::push_back(&mut manage.volunteer_ids, ctx.sender());
    vector::push_back(&mut manage.volunteer_nfts, id);
}

public(package) fun add_local_leader_to_manage(
    manage: &mut Manage,
    id: ID,
    region: String,
    ctx: &mut TxContext,
) {
    assert!(!is_leader_added(manage, ctx), ELeaderExisted);
    assert!(!is_local_region_added(manage, region), ERegionExisted);

    vector::push_back(&mut manage.local_leader_ids, ctx.sender());
    vector::push_back(&mut manage.local_leader_nfts, id);
    vector::push_back(&mut manage.local_regions, region);
}
