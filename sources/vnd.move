module raise_child::vnd;

use sui::coin::{Self, TreasuryCap};
use sui::url;

public struct VND has drop {}

fun init(witness: VND, ctx: &mut TxContext) {
    let (treausury_cap, coin_metadata) = coin::create_currency(
        witness,
        1,
        b"VND",
        b"Viet Nam Dong",
        b"Native Vietnamese Token in RaiseChild Platform, xu",
        option::some(
            url::new_unsafe_from_bytes(
                b"https://photo.znews.vn/w660/Uploaded/erlu/2014_03_31/xu20132.jpg",
            ),
        ),
        ctx,
    );

    transfer::public_freeze_object(coin_metadata);
    transfer::public_transfer(treausury_cap, ctx.sender());
}
