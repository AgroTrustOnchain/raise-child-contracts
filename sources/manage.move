module raise_child::manage;

use std::string::String;
use std::vector::push_back;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::transfer::{Self, public_transfer};
use sui::url::{Url, new_unsafe_from_bytes};

const ENotAuthorized: u64 = 1;
const EZeroAmount: u64 = 2;
const EInsufficientAmount: u64 = 3;
const EDonorExisted: u64 = 4;
const ELeaderExisted: u64 = 5;
const ERegionExisted: u64 = 6;
const EVolunteerExisted: u64 = 7;
const EMissingAdminInfo: u64 = 8;
const EAdminExisted: u64 = 9;
const EInvalidAddCenter: u64 = 10;

public struct Manage has key {
    id: UID,
    admin_nfts: vector<ID>,
    admin_ids: vector<address>,
    child_ids: vector<ID>,
    volunteer_nfts: vector<ID>,
    volunteer_ids: vector<address>,
    local_leader_nfts: vector<ID>,
    local_leader_ids: vector<address>,
    local_regions: vector<String>,
    children_centers: vector<ID>,
    center_confirm_statuses: vector<bool>,
    created_centers: vector<ID>,
    donor_nfts: vector<ID>,
    donor_ids: vector<address>,
}

public struct AdminNFT has key {
    id: UID,
    owner: address,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    uploaded_at: u64,
    name: String,
    url: Url,
}

public struct UpdateAdminInfoAfterPublishCap has key {
    id: UID,
}

public struct AdminCap has key {
    id: UID,
}

public struct RegisterVolunteerCap has key {
    id: UID,
}

public struct RegisterLocalLeaderCap has key {
    id: UID,
}

public struct UploadCenterCap has key {
    id: UID,
}

public struct RegisterAdminCap has key {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let sender = ctx.sender();
    let empty = b"Empty".to_string();
    let nft = AdminNFT {
        id: object::new(ctx),
        owner: sender,
        identity_code: empty,
        identity_card_blob_id: empty,
        avatar_blob_id: empty,
        first_name: empty,
        last_name: empty,
        gender: empty,
        date_of_birth: empty,
        phone_number: empty,
        email: empty,
        uploaded_at: 0,
        name: get_admin_nft_name(),
        url: new_unsafe_from_bytes(
            get_admin_nft_url_bytes(),
        ),
    };

    let manage = Manage {
        id: object::new(ctx),
        admin_ids: vector[],
        admin_nfts: vector[],
        child_ids: vector[],
        volunteer_nfts: vector[],
        volunteer_ids: vector[],
        local_leader_nfts: vector[],
        local_leader_ids: vector[],
        local_regions: vector[],
        children_centers: vector[],
        center_confirm_statuses: vector[],
        created_centers: vector[],
        donor_nfts: vector[],
        donor_ids: vector[],
    };

    transfer::transfer(nft, sender);
    transfer::transfer(
        UpdateAdminInfoAfterPublishCap {
            id: object::new(ctx),
        },
        sender,
    );
    transfer::transfer(AdminCap { id: object::new(ctx) }, sender);
    transfer::transfer(AdminCap { id: object::new(ctx) }, sender);
    transfer::share_object(manage);
}

public entry fun transfer_original_info(
    manage: &mut Manage,
    admin_cap: AdminCap,
    edit_cap: UpdateAdminInfoAfterPublishCap,
    mut nft: AdminNFT,
    recipient: address,
) {
    nft.owner = recipient;
    vector::push_back(&mut manage.admin_nfts, nft.id.to_inner());
    vector::push_back(&mut manage.admin_ids, recipient);

    transfer::transfer(nft, recipient);
    transfer::transfer(edit_cap, recipient);
    transfer::transfer(admin_cap, recipient);
}

public fun update_publisher_nft(
    cap: UpdateAdminInfoAfterPublishCap,
    nft: &mut AdminNFT,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let empty = b"Empty".to_string();
    assert!(
        identity_code != empty && identity_card_blob_id != empty && avatar_blob_id != empty && first_name != empty && last_name != empty && gender != empty && phone_number != empty && email != empty && date_of_birth != empty,
        EMissingAdminInfo,
    );

    nft.identity_code = identity_code;
    nft.identity_card_blob_id = identity_card_blob_id;
    nft.avatar_blob_id = avatar_blob_id;
    nft.first_name = first_name;
    nft.last_name = last_name;
    nft.gender = gender;
    nft.date_of_birth = date_of_birth;
    nft.phone_number = phone_number;
    nft.email = email;
    nft.uploaded_at = clock::timestamp_ms(clock);

    let UpdateAdminInfoAfterPublishCap { id } = cap;
    object::delete(id);
}

public fun mint_register_volunteer_cap(_: &AdminCap, recipient: address, ctx: &mut TxContext) {
    transfer::transfer(RegisterVolunteerCap { id: object::new(ctx) }, recipient);
}

public fun mint_register_local_leader_cap(_: &AdminCap, recipient: address, ctx: &mut TxContext) {
    transfer::transfer(RegisterLocalLeaderCap { id: object::new(ctx) }, recipient);
}

public fun mint_register_admin_cap(_: &AdminCap, recipient: address, ctx: &mut TxContext) {
    transfer::transfer(RegisterAdminCap { id: object::new(ctx) }, recipient);
}

public fun mint_upload_center_cap(_: &AdminCap, recipient: address, ctx: &mut TxContext) {
    transfer::transfer(UploadCenterCap { id: object::new(ctx) }, recipient);
}

public(package) fun mint_admin_nft(
    manage: &mut Manage,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!is_admin_added(manage, ctx), EAdminExisted);

    let empty = b"".to_string();
    assert!(
        identity_code != empty && identity_card_blob_id != empty && avatar_blob_id != empty && first_name != empty && last_name != empty && gender != empty && phone_number != empty && email != empty && date_of_birth != empty,
        EMissingAdminInfo,
    );

    let sender = ctx.sender();
    let nft = AdminNFT {
        id: object::new(ctx),
        owner: sender,
        identity_code: identity_code,
        identity_card_blob_id: identity_card_blob_id,
        avatar_blob_id: avatar_blob_id,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        phone_number: phone_number,
        email: email,
        uploaded_at: clock::timestamp_ms(clock),
        name: get_admin_nft_name(),
        url: new_unsafe_from_bytes(
            get_admin_nft_url_bytes(),
        ),
    };

    vector::push_back(&mut manage.admin_ids, sender);
    vector::push_back(&mut manage.admin_nfts, nft.id.to_inner());
    transfer::transfer(nft, sender);
}

public(package) fun burn_register_admin_cap(cap: RegisterAdminCap, ctx: &mut TxContext) {
    let RegisterAdminCap { id } = cap;
    object::delete(id);
}

public(package) fun burn_register_volunteer_cap(cap: RegisterVolunteerCap, ctx: &mut TxContext) {
    let RegisterVolunteerCap { id } = cap;
    object::delete(id);
}

public(package) fun burn_register_local_leader_cap(
    cap: RegisterLocalLeaderCap,
    ctx: &mut TxContext,
) {
    let RegisterLocalLeaderCap { id } = cap;
    object::delete(id);
}

public(package) fun burn_upload_center_cap(cap: UploadCenterCap, ctx: &mut TxContext) {
    let UploadCenterCap { id } = cap;
    object::delete(id);
}

public(package) fun is_withdraw_requestor_valid(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.admin_ids, &ctx.sender());
    found || is_donor_added(manage, ctx) || is_leader_added(manage, ctx) || is_volunteer_added(manage, ctx)
}

public(package) fun is_donor_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.donor_ids, &ctx.sender());
    found
}

public(package) fun is_donor_added_v2(manage: &mut Manage, sender: address): bool {
    let (found, _) = vector::index_of(&mut manage.donor_ids, &sender);
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

public(package) fun is_center_status_created(manage: &mut Manage, region: String): bool {
    let (found_region, region_idx) = vector::index_of(&mut manage.local_regions, &region);
    if (!found_region) {
        return false;
    };

    *vector::borrow(&mut manage.center_confirm_statuses, region_idx)
}

public(package) fun is_create_children_center_requestor_valid(
    manage: &mut Manage,
    region: String,
    ctx: &mut TxContext,
): bool {
    let (region_found, region_idx) = vector::index_of(&mut manage.local_regions, &region);
    let (leader_found, leader_idx) = vector::index_of(&mut manage.local_leader_ids, &ctx.sender());
    let status_ref = vector::borrow(&mut manage.center_confirm_statuses, region_idx);

    region_found && leader_found && region_idx == leader_idx && !*status_ref
}

public(package) fun is_admin_added(manage: &mut Manage, ctx: &mut TxContext): bool {
    let (found, _) = vector::index_of(&mut manage.admin_ids, &ctx.sender());
    found
}

fun get_admin_nft_name(): String {
    b"RaiseChild Admin NFT".to_string()
}

fun get_admin_nft_url_bytes(): vector<u8> {
    b"some-link"
}

public(package) fun add_temporary_children_center(
    manage: &mut Manage,
    region: String,
    ctx: &mut TxContext,
) {
    let uid = object::new(ctx);
    vector::push_back(&mut manage.children_centers, uid.to_inner());
    vector::push_back(&mut manage.center_confirm_statuses, false);
    object::delete(uid);
}

public(package) fun add_children_center_to_manage(
    manage: &mut Manage,
    cap: UploadCenterCap,
    region: String,
    id: ID,
    ctx: &mut TxContext,
) {
    let (found_region, region_idx) = vector::index_of(&mut manage.local_regions, &region);
    let status_ref = vector::borrow_mut(&mut manage.center_confirm_statuses, region_idx);
    assert!(found_region && *status_ref, EInvalidAddCenter);

    let center_ref = vector::borrow_mut(&mut manage.children_centers, region_idx);
    *center_ref = id;
    *status_ref = true;
    vector::push_back(&mut manage.created_centers, id);

    let UploadCenterCap { id: cap_id } = cap;
    object::delete(cap_id);
}

public(package) fun add_donor_to_manage(manage: &mut Manage, ctx: &mut TxContext) {
    assert!(!is_donor_added(manage, ctx), EDonorExisted);
    vector::push_back(&mut manage.donor_ids, ctx.sender());
}

public(package) fun add_donor_to_manage_v2(manage: &mut Manage, sender: address) {
    assert!(!is_donor_added_v2(manage, sender), EDonorExisted);
    vector::push_back(&mut manage.donor_ids, sender);
}

public(package) fun add_donor_to_manage_v3(manage: &mut Manage, donor_id: ID, ctx: &mut TxContext) {
    assert!(!is_donor_added(manage, ctx), EDonorExisted);
    vector::push_back(&mut manage.donor_ids, ctx.sender());
    vector::push_back(&mut manage.donor_nfts, donor_id);
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
