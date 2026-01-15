module raise_child::sponsor;

use raise_child::manage::{Manage, is_sponsor_added};
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

public(package) fun get_sponsor_donate_amount(sponsor: &mut SponsorNFT): u128 {
    sponsor.total_donation
}
