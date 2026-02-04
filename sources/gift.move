module raise_child::gift;

use raise_child::child::{Child, add_gift, get_child_inner_id, get_child_region};
use raise_child::manage::{
    Manage,
    is_sponsor_added,
    is_sponsor_added_v2,
    add_sponsor_to_manage,
    add_sponsor_to_manage_v2
};
use raise_child::record::create_tx_record;
use raise_child::sponsor::{SponsorNFT, mint_sponsor_nft, update_donation_after_donate};
use raise_child::staff::{StaffNFT, is_staff_matched_region};
use std::string::String;
use sui::clock::{Self, Clock};

const EInvalidAmount: u64 = 1;
const ENotGiftSender: u64 = 2;
const EInvalidCancelGift: u64 = 3;
const EInvalidConfirmRecieved: u64 = 4;
const EMissingRecievedProff: u64 = 5;
const EAlreadyConfirmed: u64 = 6;
const ENotStaffInRegion: u64 = 7;

public struct Gift has key {
    id: UID,
    sender: address,
    child_id: ID,
    tracking_code: String,
    carrier: String,
    gift_image_blob_id: String,
    status: String,
    category: String,
    description: String,
    message: String,
    cancel_reason: String,
    delivered_image_blob_id: String,
    uploaded_at: u64,
    updated_at: u64,
    delivered_at: u64,
    confirm_recieved_by: address,
}

public fun create_gift(
    manage: &mut Manage,
    sponsor: &mut SponsorNFT,
    child: &mut Child,
    tracking_code: String,
    carrier: String,
    gift_image_blob_id: String,
    category: String,
    amount: u128,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    description: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(amount >= 2000, EInvalidAmount);
    if (!is_sponsor_added(manage, ctx)) {
        mint_sponsor_nft(
            manage,
            first_name,
            last_name,
            gender,
            phone_number,
            email,
            amount,
            ctx,
        );
        add_sponsor_to_manage(manage, ctx);
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
    };

    create_tx_record(
        amount,
        b"VND".to_string(),
        b"Give gift".to_string(),
        b"Child".to_string(),
        message,
        clock,
        ctx,
    );

    let cur_time = clock::timestamp_ms(clock);
    let sender = ctx.sender();
    let gift = Gift {
        id: object::new(ctx),
        sender: sender,
        child_id: get_child_inner_id(child),
        tracking_code: tracking_code,
        carrier: carrier,
        gift_image_blob_id: gift_image_blob_id,
        status: get_pending_status(),
        category: category,
        description: description,
        message: message,
        cancel_reason: b"".to_string(),
        delivered_image_blob_id: b"".to_string(),
        uploaded_at: cur_time,
        updated_at: cur_time,
        delivered_at: 0,
        confirm_recieved_by: sender,
    };

    add_gift(child, gift.id.to_inner());
    transfer::share_object(gift);
}

public fun cancel_gift(gift: &mut Gift, cancel_reason: String, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == gift.sender, ENotGiftSender);
    assert!(gift.status == get_pending_status(), EInvalidCancelGift);

    gift.status = get_cancel_status();
    gift.cancel_reason = cancel_reason;
    gift.updated_at = clock::timestamp_ms(clock);
}

public fun confirm_recieved(
    gift: &mut Gift,
    child: &Child,
    staff: &StaffNFT,
    image_blob_id: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(gift.status == get_pending_status(), EInvalidConfirmRecieved);
    assert!(gift.confirm_recieved_by == gift.sender, EAlreadyConfirmed);
    assert!(image_blob_id != b"".to_string(), EMissingRecievedProff);
    assert!(is_staff_matched_region(staff, get_child_region(child)), ENotStaffInRegion);

    gift.delivered_image_blob_id = image_blob_id;
    gift.status = get_delivered_status();
    gift.delivered_at = clock::timestamp_ms(clock);
    gift.confirm_recieved_by = ctx.sender();
}

// public fun confirm_recieved(
//     manage: &mut Manage,
//     sponsor: &mut SponsorNFT,
//     first_name: String,
//     last_name: String,
//     gender: String,
//     phone_number: String,
//     email: String,
//     gift: &mut Gift,
//     child: &Child,
//     staff: &StaffNFT,
//     image_blob_id: String,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     assert!(gift.status == get_pending_status(), EInvalidConfirmRecieved);
//     assert!(gift.confirm_recieved_by == gift.sender, EAlreadyConfirmed);
//     assert!(image_blob_id != b"".to_string(), EMissingRecievedProff);
//     assert!(is_staff_matched_region(staff, get_child_region(child)), ENotStaffInRegion);

//     if (!is_sponsor_added_v2(manage, gift.sender)) {
//         mint_sponsor_nft_v2(
//             manage,
//             first_name,
//             last_name,
//             gender,
//             phone_number,
//             email,
//             gift.gift_value,
//             gift.sender,
//             ctx,
//         );
//         add_sponsor_to_manage_v2(manage, gift.sender);
//     };

//     gift.delivered_image_blob_id = image_blob_id;
//     gift.status = get_delivered_status();
//     gift.delivered_at = clock::timestamp_ms(clock);
//     gift.confirm_recieved_by = ctx.sender();
// }

fun get_pending_status(): String {
    b"Pending".to_string()
}

fun get_cancel_status(): String {
    b"Cancel".to_string()
}

fun get_delivered_status(): String {
    b"Delivered".to_string()
}
