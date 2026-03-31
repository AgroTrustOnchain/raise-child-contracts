module raise_child::staff;

use raise_child::manage::{
    Manage,
    add_volunteer_to_manage,
    add_local_leader_to_manage,
    add_temporary_children_center,
    is_local_region_added,
    is_center_status_created,
    mint_admin_nft,
    burn_register_volunteer_cap,
    burn_register_local_leader_cap,
    burn_register_admin_cap,
    RegisterVolunteerCap,
    RegisterLocalLeaderCap,
    RegisterAdminCap
};
use raise_child::pool::{VndPool, LocalPool, add_leader_to_pool};
use std::string::String;
use sui::clock::{Self, Clock};
use sui::url::{Url, new_unsafe_from_bytes};

const ERegionAdded: u64 = 1;
const ERegionNotExist: u64 = 2;
const EStaffMissingInfo: u64 = 3;

public struct StaffNFT has key {
    id: UID,
    owner: address,
    role: String,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    region: String,
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

fun is_staff_info_enough(
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
): bool {
    let empty = b"".to_string();
    identity_code != empty && identity_card_blob_id != empty && avatar_blob_id != empty && 
    region != empty && first_name != empty && last_name != empty && gender != empty &&
    date_of_birth != empty && phone_number != empty && email != empty
}

fun get_role(is_leader: bool): String {
    let role_bytes = if (is_leader) b"Local Leader" else b"Volunteer";
    role_bytes.to_string()
}

fun get_nft_name(is_leader: bool): String {
    let name_bytes = if (is_leader) b"AgroTrust Local Leader NFT" else b"AgroTrust Volunteer NFT";
    name_bytes.to_string()
}

fun get_nft_url_bytes(is_leader: bool): vector<u8> {
    if (is_leader)
        b"https://thumbs.dreamstime.com/b/leader-icon-vector-male-public-speaker-person-symbol-leadership-raised-hand-glyph-pictogram-illustration-117769150.jpg"
    else b"https://www.clipartmax.com/png/middle/96-967024_picture-volunteer-icon-png.png"
}

public fun register_staff(
    manage: &mut Manage,
    pool: &mut VndPool,
    identity_code: String,
    identity_card_blob_id: String,
    role: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (role == b"Admin".to_string()) {
        mint_admin_nft(
            manage,
            identity_code,
            identity_card_blob_id,
            avatar_blob_id,
            first_name,
            last_name,
            gender,
            date_of_birth,
            phone_number,
            email,
            clock,
            ctx,
        );
        return
    };

    let staff_id = object::new(ctx);
    let volunteer_role = b"Volunteer".to_string();
    let leader_role = b"Local Leader".to_string();
    let name_bytes: vector<u8>;
    let url_bytes: vector<u8>;

    if (role == volunteer_role) {
        name_bytes = b"Agro Volunteer NFT";
        url_bytes = b"some-link";
        add_volunteer_to_manage(manage, staff_id.to_inner(), ctx);
    } else {
        assert!(!is_local_region_added(manage, region), ERegionAdded);
        name_bytes = b"Agro Local Leader NFT";
        url_bytes = b"some-link";
        add_local_leader_to_manage(manage, staff_id.to_inner(), region, ctx);
    };

    let user = ctx.sender();
    let staff = StaffNFT {
        id: staff_id,
        owner: user,
        role: role,
        identity_code: identity_code,
        identity_card_blob_id: identity_card_blob_id,
        avatar_blob_id: avatar_blob_id,
        region: region,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        phone_number: phone_number,
        email: email,
        uploaded_at: clock::timestamp_ms(clock),
        name: name_bytes.to_string(),
        url: new_unsafe_from_bytes(
            url_bytes,
        ),
    };

    if (role == leader_role) {};

    transfer::transfer(staff, user);
}

public fun register_admin(
    manage: &mut Manage,
    cap: RegisterAdminCap,
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
    mint_admin_nft(
        manage,
        identity_code,
        identity_card_blob_id,
        avatar_blob_id,
        first_name,
        last_name,
        gender,
        date_of_birth,
        phone_number,
        email,
        clock,
        ctx,
    );

    burn_register_admin_cap(cap, ctx);
}

public fun register_volunteer(
    manage: &mut Manage,
    cap: RegisterVolunteerCap,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_info_enough(
            identity_code,
            identity_card_blob_id,
            avatar_blob_id,
            region,
            first_name,
            last_name,
            gender,
            date_of_birth,
            phone_number,
            email,
        ),
        EStaffMissingInfo,
    );
    assert!(is_local_region_added(manage, region), ERegionNotExist);

    let sender = ctx.sender();
    let nft = StaffNFT {
        id: object::new(ctx),
        owner: sender,
        role: get_role(false),
        identity_code: identity_code,
        identity_card_blob_id: identity_card_blob_id,
        avatar_blob_id: avatar_blob_id,
        region: region,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        phone_number: phone_number,
        email: email,
        uploaded_at: clock::timestamp_ms(clock),
        name: get_nft_name(false),
        url: new_unsafe_from_bytes(
            get_nft_url_bytes(false),
        ),
    };

    add_volunteer_to_manage(manage, nft.id.to_inner(), ctx);
    transfer::transfer(nft, sender);
    burn_register_volunteer_cap(cap, ctx);
}

public fun register_local_leader(
    manage: &mut Manage,
    cap: RegisterLocalLeaderCap,
    pool: &mut LocalPool,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_info_enough(
            identity_code,
            identity_card_blob_id,
            avatar_blob_id,
            region,
            first_name,
            last_name,
            gender,
            date_of_birth,
            phone_number,
            email,
        ),
        EStaffMissingInfo,
    );

    let sender = ctx.sender();
    let nft = StaffNFT {
        id: object::new(ctx),
        owner: sender,
        role: get_role(true),
        identity_code: identity_code,
        identity_card_blob_id: identity_card_blob_id,
        avatar_blob_id: avatar_blob_id,
        region: region,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        phone_number: phone_number,
        email: email,
        uploaded_at: clock::timestamp_ms(clock),
        name: get_nft_name(true),
        url: new_unsafe_from_bytes(
            get_nft_url_bytes(true),
        ),
    };

    add_local_leader_to_manage(manage, nft.id.to_inner(), region, ctx);
    transfer::transfer(nft, sender);
    if (!is_local_region_added(manage, region)) {
        add_temporary_children_center(manage, region, ctx);
    } else {
        if (is_center_status_created(manage, region)) {
            add_leader_to_pool(pool, ctx);
        };
    };

    burn_register_local_leader_cap(cap, ctx);
}

public(package) fun is_staff_matched_region(staff: &StaffNFT, region: String): bool {
    staff.region == region
}

public(package) fun get_staff_region(staff: &StaffNFT): String {
    staff.region
}

public(package) fun is_local_leader(staff: &StaffNFT): bool {
    staff.role == b"Local Leader".to_string()
}
