# Setting up gamepasses and developer products

The game already contains all the purchase logic. You only need to create the items on Roblox and paste their Ids into `src/Shared/Config.lua`.
Until an Id is filled in, its shop button shows a message saying it isn't configured yet.

## 1. Publish the experience first

In Roblox Studio, choose **File > Publish to Roblox** and create a new experience.
Passes and products belong to an experience, so it has to exist first.

## 2. Create the gamepasses

1. Go to the [Creator Hub](https://create.roblox.com/dashboard/creations) and click your experience.
2. Open **Monetization > Passes** and click **Create a Pass**.
3. Upload an icon, enter the name and description, and click **Create Pass**.
4. Open the pass, go to **Sales**, turn **Item for Sale** on, and set the price.
5. Copy the pass's **Asset ID**. It is also the number in the pass's web address.
6. Paste it into the matching entry in `Config.Gamepasses`:

```lua
DoubleCoins = {
	Id = 123456789, -- <<< your pass id
	Name = "2x Coins",
	Price = 249,    -- shown in the shop; keep it equal to the real price
	...
},
```

Create one pass for each entry: `DoubleCoins`, `VIP`, `AutoCollect`, `Lucky`, `ExtraPetSlots`, `TripleHatch`, `AutoHatch`.

## 3. Create the developer products

1. In the same experience, open **Monetization > Developer Products** and click **Create a Developer Product**.
2. Give it a name, icon and price, then save.
3. Copy its **Product ID** and paste it into the matching entry in `Config.Products`.

Create one product for each entry: `Coins_Small`, `Coins_Medium`, `Coins_Large`, `Coins_Mega`, `Gems_Small`, `Gems_Medium`, `Gems_Large`, `LuckPotion`, `CoinPotion`, `RebirthToken`.

The `Price` field in Config only controls the label in the in-game shop. Roblox always charges the price set on the Creator Hub, so keep them equal.

## 4. Test it

- In Studio, purchases go through a fake test prompt and no Robux are spent.
- Set `Config.Debug.FreeGamepassesInStudio = false` to test the real gamepass flow. Leave it `true` to try every pass's effect without buying.
- Watch the Output window. A purchase for an Id that isn't in Config prints a warning naming the missing Id.

## How purchases are kept safe

- **Gamepasses** are checked with `UserOwnsGamePassAsync` when a player joins, and granted the moment a purchase finishes.
- **Developer products** go through `ProcessReceipt`. Each purchase Id is recorded in the player's save, so a purchase is never granted twice.
- The save is written **before** Roblox is told the purchase succeeded. If saving fails, Roblox retries the receipt later, and the duplicate check stops a double grant.

## Pricing tips

- Keep one cheap item at R$49 to R$99. A player's first purchase is the hardest one, and a low price gets it.
- Gamepasses that save time sell best in simulators: 2x Coins, Auto Collect, Triple Hatch and Auto Hatch.
- Use limited-time potions and boosts during update weekends to drive repeat purchases.
- Try the Creator Hub's price testing tools once you have steady traffic, instead of guessing.

## Paid random items rules

Coins and gems can be bought with Robux, so every egg counts as a paid random item under Roblox's rules. The game already follows the main requirements:

- Every egg shows all possible pets and their exact odds before hatching. The numbers always add up to exactly 100%.
- When Lucky or a luck potion is active, the displayed odds update to the boosted numbers.
- The server asks Roblox's `PolicyService` whether each player is in a region that restricts paid random items. For those players, the shop blocks coin packs, gem packs, the Lucky pass and the luck potion. Their eggs are paid for only with currency earned by playing.

If you add new ways to buy currency or luck, add their keys to `Config.RestrictedPurchases` so restricted players can't buy them.
Read the official [paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items) before adding anything random that can be paid for.
