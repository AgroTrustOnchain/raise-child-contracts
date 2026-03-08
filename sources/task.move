module raise_child::task;

use std::string::String;
use sui::clock::{Self, Clock};
use sui::object;

public struct ProofOfTask has key {
    id: UID,
    actor: address,
    description: String,
    image_blob_id: String,
    uploaded_at: u64,
}

public(package) fun create_proof_of_task(
    description: String,
    image_blob_id: String,
    actor: address,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let proof = ProofOfTask {
        id: object::new(ctx),
        actor: actor,
        description: description,
        image_blob_id: image_blob_id,
        uploaded_at: clock::timestamp_ms(clock),
    };

    let id = proof.id.to_inner();
    transfer::transfer(proof, actor);
    id
}
