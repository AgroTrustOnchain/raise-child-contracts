module raise_child::staff;

use raise_child::manage::{Manage, add_volunteer_to_manage, add_local_leader_to_manage};
use raise_child::staff;
use std::string::{Self, String, utf8};
use sui::clock::{Self, Clock};
use sui::url::{Url, new_unsafe_from_bytes};

public struct Staff has key {
    id: UID,
    user: address,
    role: String,
    identity_code: String,
    identity_card_blob_id: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    uploaded_at: u64,
}

public struct StaffNFT has key {
    id: UID,
    identity_code: String,
    role: String,
    first_name: String,
    last_name: String,
    name: String,
    url: Url,
}

public fun register_staff(
    manage: &mut Manage,
    identity_code: String,
    identity_card_blob_id: String,
    role: String,
    avatar_blob_id: String,
    region: String,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let user = ctx.sender();
    let staff = Staff {
        id: object::new(ctx),
        user: user,
        role: role,
        identity_code: identity_code,
        identity_card_blob_id: identity_card_blob_id,
        avatar_blob_id: avatar_blob_id,
        region: region,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        phone_number: phone_number,
        email: email,
        uploaded_at: clock::timestamp_ms(clock),
    };

    let staff_id = staff.id.to_inner();
    transfer::transfer(staff, user);

    let volunteer_role = b"Volunteer".to_string();
    let name_bytes: vector<u8>;
    let url_bytes: vector<u8>;

    if (role == volunteer_role) {
        name_bytes = b"RaiseChild Volunteer NFT";
        url_bytes = b"some-link";
        add_volunteer_to_manage(manage, staff_id, ctx);
    } else {
        name_bytes = b"RaiseChild Local Leader NFT";
        url_bytes = b"some-link";
        add_local_leader_to_manage(manage, staff_id, ctx);
    };

    let nft = StaffNFT {
        id: object::new(ctx),
        identity_code: identity_code,
        role: role,
        first_name: first_name,
        last_name: last_name,
        name: name_bytes.to_string(),
        url: new_unsafe_from_bytes(
            url_bytes,
        ),
    };

    transfer::transfer(nft, user);
}
