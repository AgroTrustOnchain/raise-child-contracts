module raise_child::donor;

use raise_child::manage::{Manage, is_donor_added, is_donor_added_v2, add_donor_to_manage_v3};
use std::string::{Self, String, utf8};
use sui::url::{Url, new_unsafe_from_bytes};

const ENftExisted: u64 = 1;

public struct DonorNFT has key {
    id: UID,
    owner: address,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    total_donation: u64,
    name: String,
    url: Url,
}

fun init(ctx: &mut TxContext) {
    let empty = b"".to_string();
    transfer::share_object(DonorNFT {
        id: object::new(ctx),
        owner: ctx.sender(),
        first_name: empty,
        last_name: empty,
        gender: empty,
        phone_number: empty,
        email: empty,
        total_donation: 0,
        name: b"RaiseChild Donor NFT".to_string(),
        url: new_unsafe_from_bytes(b"some-link"),
    });
}

public(package) fun mint_donor_nft(
    manage: &mut Manage,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    amount: u64,
    ctx: &mut TxContext,
) {
    if (!is_donor_added(manage, ctx)) {
        let owner = ctx.sender();
        let nft = DonorNFT {
            id: object::new(ctx),
            owner: owner,
            first_name: first_name,
            last_name: last_name,
            gender: gender,
            phone_number: phone_number,
            email: email,
            total_donation: amount,
            name: b"RaiseChild Donor NFT".to_string(),
            url: new_unsafe_from_bytes(b"some-link"),
        };

        add_donor_to_manage_v3(manage, nft.id.to_inner(), ctx);
        transfer::transfer(nft, ctx.sender());
    }
}

public(package) fun mint_donor_nft_v2(
    manage: &mut Manage,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    amount: u64,
    ctx: &mut TxContext,
): ID {
    let owner = ctx.sender();
    let nft = DonorNFT {
        id: object::new(ctx),
        owner: owner,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        phone_number: phone_number,
        email: email,
        total_donation: amount,
        name: b"RaiseChild Donor NFT".to_string(),
        url: new_unsafe_from_bytes(b"some-link"),
    };

    let id = nft.id.to_inner();
    add_donor_to_manage_v3(manage, id, ctx);
    transfer::transfer(nft, owner);
    id
}

public(package) fun update_donation_after_donate(
    donor: &mut DonorNFT,
    amount: u64,
    ctx: &mut TxContext,
) {
    donor.total_donation = donor.total_donation + amount;
}

public(package) fun get_donor_donate_amount(donor: &mut DonorNFT, ctx: &mut TxContext): u64 {
    donor.total_donation
}

public(package) fun get_donor_id(donor: &mut DonorNFT): ID {
    donor.id.to_inner()
}
