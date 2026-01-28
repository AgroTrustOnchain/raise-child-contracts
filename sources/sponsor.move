module raise_child::sponsor;

use raise_child::manage::{Manage, is_sponsor_added, is_sponsor_added_v2};
use std::string::{Self, String, utf8};
use sui::url::{Url, new_unsafe_from_bytes};

const ENftExisted: u64 = 1;

public struct SponsorNFT has key {
    id: UID,
    owner: address,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    total_donation: u128,
    name: String,
    url: Url,
}

fun init(ctx: &mut TxContext) {
    let empty = b"".to_string();
    transfer::share_object(SponsorNFT {
        id: object::new(ctx),
        owner: ctx.sender(),
        first_name: empty,
        last_name: empty,
        gender: empty,
        phone_number: empty,
        email: empty,
        total_donation: 0,
        name: b"RaiseChild Sponsor NFT".to_string(),
        url: new_unsafe_from_bytes(b"some-link"),
    });
}

public(package) fun mint_sponsor_nft(
    manage: &mut Manage,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    amount: u128,
    ctx: &mut TxContext,
) {
    if (!is_sponsor_added(manage, ctx)) {
        let owner = ctx.sender();
        let nft = SponsorNFT {
            id: object::new(ctx),
            owner: owner,
            first_name: first_name,
            last_name: last_name,
            gender: gender,
            phone_number: phone_number,
            email: email,
            total_donation: amount,
            name: b"RaiseChild Sponsor NFT".to_string(),
            url: new_unsafe_from_bytes(b"some-link"),
        };

        transfer::transfer(nft, ctx.sender());
    }
}

public(package) fun mint_sponsor_nft_v2(
    manage: &mut Manage,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    amount: u128,
    owner: address,
    ctx: &mut TxContext,
) {
    if (!is_sponsor_added_v2(manage, owner)) {
        let nft = SponsorNFT {
            id: object::new(ctx),
            owner: owner,
            first_name: first_name,
            last_name: last_name,
            gender: gender,
            phone_number: phone_number,
            email: email,
            total_donation: amount,
            name: b"RaiseChild Sponsor NFT".to_string(),
            url: new_unsafe_from_bytes(b"some-link"),
        };

        transfer::transfer(nft, owner);
    }
}

public(package) fun update_donation_after_donate(
    sponsor: &mut SponsorNFT,
    amount: u128,
    ctx: &mut TxContext,
) {
    sponsor.total_donation = sponsor.total_donation + amount;
}

public(package) fun get_sponsor_donate_amount(sponsor: &mut SponsorNFT, ctx: &mut TxContext): u128 {
    sponsor.total_donation
}
