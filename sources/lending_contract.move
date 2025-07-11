module 0x0::lending;


/// Constants

// Pool image or metadata URL
const URL: vector<u8> = b"https://x.com/SuiHubAfrica/photo";

// Error codes
const ERR_INSUFFICIENT_FUND: u64 = 0;
const ERR_LP_NOT_FOUND: u64 = 0;

/// Represents a lending pool where users can deposit SUI and others can borrow from it.
public struct LendingPool has key, store {
    id: UID,
    /// Name of the lending pool
    name: vector<u8>,
    /// Creator of the pool
    creator: address,
    /// Total SUI balance in the pool
    worth: sui::balance::Balance<sui::sui::SUI>,
    /// Total amount borrowed (not currently used)
    total_borrows: u64,
    /// URL for external pool metadata
    url: sui::url::Url,
    /// Fixed compensation or interest rate (e.g., 10%)
    compasation: u64,
    /// List of liquidity provider addresses
    list_lp: vector<address>
}

/// Represents a loan taken from the pool
public struct Loan has key, store {
    id: UID,
    /// Address of the borrower
    borrower: address,
    /// Interest amount to repay (includes principal + fee)
    interest: u64,
}

/// Represents a liquidity provider’s contribution to the pool
public struct Liquidity_Provider has store, key {
    id: UID,
    /// Contribution value (e.g. 2% of deposit)
    val: u64,
}

/// Initializes a new lending pool with default values
fun init(ctx: &mut TxContext) {
    let pool = LendingPool {
        id: object::new(ctx),
        name: b"SHL",
        creator: ctx.sender(),
        worth: sui::balance::zero(),
        total_borrows: 0,
        url: sui::url::new_unsafe(URL.to_ascii_string()),
        compasation: 10,
        list_lp: vector::empty<address>()
    };

    // Shares the pool object to allow access from outside the module
    transfer::share_object(pool);
}

/// Deposits SUI into the pool from the sender's balance
/// - `amount`: amount to deposit
/// - `recipient_balance`: sender’s coin object to deduct from
/// - `pool`: the pool to deposit into
/// - `ctx`: transaction context
public entry fun deposit(
    amount: u64,
    recipient_balance: &mut sui::coin::Coin<sui::sui::SUI>,
    pool: &mut LendingPool,
    ctx: &mut TxContext,
) {
    // Ensure the user has enough balance
    assert!(recipient_balance.value() >= amount, ERR_INSUFFICIENT_FUND);

    // Split the amount from their balance
    let rm_coin = recipient_balance.split(amount, ctx);

    // Add the split coin to the pool's balance
    pool.worth.join(rm_coin.into_balance());

    // Calculate 2% contribution (NOTE: fix integer division to `amount * 2 / 100`)
    let contr_percentage = amount * 2 / 100;

    // Create new Liquidity_Provider object
    let new_lp_obj = object::new(ctx);
    let bw_new_lp_id = &new_lp_obj;

    // Track LP address
    vector::push_back(&mut pool.list_lp, bw_new_lp_id.to_address());

    // Mint and send LP object to the depositor
    let i = Liquidity_Provider {
        id: new_lp_obj,
        val: contr_percentage
    };

    transfer::public_transfer(i, ctx.sender());
}

/// Allows a user to borrow a specified `amount` from the pool
/// - Deducts funds from the pool
/// - Creates a Loan object
/// - Transfers both the borrowed funds and loan object to the borrower
public entry fun borrow(
    amount: u64,
    pool: &mut LendingPool,
    ctx: &mut TxContext
) {
    let borrower = ctx.sender();

    // Remove the borrowed amount from the pool
    let get_balance = pool.worth.split(amount);

    // Calculate interest (amount + 2%) — fix division logic
    let interest = amount + (amount * 2 / 100);

    // Convert balance into coin form
    let get_balance_in_coin = get_balance.into_coin(ctx);

    // Create a loan object
    let create_loan = Loan {
        id: object::new(ctx),
        borrower,
        interest
    };

    // Send loan object and borrowed coin to the user
    transfer::public_transfer(create_loan, borrower);
    transfer::public_transfer(get_balance_in_coin, borrower);
}

/// Repays a loan by sending the owed amount back to the pool
/// - `pool`: LendingPool to credit repayment
/// - `loan`: Loan object containing the interest due
/// - `coin`: Coin object with funds to repay
/// - `ctx`: transaction context
public entry fun repay(
    pool: &mut LendingPool,
    loan: &mut Loan,
    coin: &mut sui::coin::Coin<sui::sui::SUI>,
    ctx: &mut TxContext,
) {
    let total_repay = loan.interest;

    // Deduct repayment from user’s coin
    let repay_coin = coin.split(total_repay, ctx);

    // Add repayment back to the pool
    pool.worth.join(repay_coin.into_balance());
}
