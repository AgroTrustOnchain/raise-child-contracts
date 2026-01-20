module raise_child::staff;

use raise_child::manage::{
    Manage,
    add_volunteer_to_manage,
    add_local_leader_to_manage,
    is_local_region_added,
    is_leader_added,
    mint_admin_nft
};
use raise_child::pool::{VndPool, create_local_pool};
use std::string::{Self, String, utf8};
use std::u128::to_string;
use sui::clock::{Self, Clock};
use sui::url::{Url, new_unsafe_from_bytes};

const ERegionAdded: u64 = 1;

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

// public struct StaffNFT has key {
//     id: UID,
//     identity_code: String,
//     role: String,
//     first_name: String,
//     last_name: String,
//     name: String,
//     url: Url,
// }

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
        name_bytes = b"RaiseChild Volunteer NFT";
        url_bytes = b"some-link";
        add_volunteer_to_manage(manage, staff_id.to_inner(), ctx);
    } else {
        assert!(!is_local_region_added(manage, region), ERegionAdded);
        name_bytes = b"RaiseChild Local Leader NFT";
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

    if (role == leader_role) {
        create_local_pool(pool, region, ctx);
    };

    transfer::transfer(staff, user);
}
