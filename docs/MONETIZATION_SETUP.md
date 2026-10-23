# Setting up gamepasses and developer products

The game already contains all the purchase logic. You only need to create the items on Roblox and paste their Ids into `src/Shared/Config.lua`.
Until an Id is filled in, its button shows a message saying it isn't configured yet.

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
DoubleJump = {
	Id = 123456789, -- <<< your pass id
	Name = "Double Jump",
	Price = 149,    -- shown in the shop; keep it equal to the real price
	...
},
```

Create one pass for each entry: `VIP`, `DoubleCoins`, `DoubleJump`, `SpeedBoost`, `LegendPack`, `RainbowTrail`.

## 3. Create the developer products

1. In the same experience, open **Monetization > Developer Products** and click **Create a Developer Product**.
2. Give it a name, icon and price, then save.
3. Copy its **Product ID** and paste it into the matching entry in `Config.Products`.

Create one product for each entry: `Skip_1`, `Skip_5`, `Skip_10`, `Coins_Small`, `Coins_Medium`, `Coins_Large`.

`Skip_1` is the product behind the big green **SKIP STAGE** button on the HUD (`Config.SkipProduct`). Make that one first.

The `Price` field in Config only controls the label in the in-game shop. Roblox always charges the price set on the Creator Hub, so keep them equal.

## 4. Test it

- In Studio, purchases go through a fake test prompt and no Robux are spent.
- Set `Config.Debug.FreeGamepassesInStudio = false` to test the real gamepass flow. Leave it `true` to try every pass's effect without buying.
- Watch the Output window. A purchase for an Id that isn't in Config prints a warning naming the missing Id.

## How purchases are kept safe

- **Gamepasses** are checked with `UserOwnsGamePassAsync` when a player joins, and granted the moment a purchase finishes.
- **Developer products** go through `ProcessReceipt`. Each purchase Id is recorded in the player's save, so a purchase is never granted twice.
- The save is written **before** Roblox is told the purchase succeeded. If saving fails, Roblox retries the receipt later, and the duplicate check stops a double grant.
- Stage skips only ever come from a processed receipt. There is no remote a cheater could call to skip for free.

## Pricing tips

- Skips are the main income in obbies. Keep the single skip cheap (R$29) so it is an easy impulse buy, and offer bundles for players who are far behind their friends.
- Keep one gamepass under R$100 (Speed Boost, Rainbow Trail). A player's first purchase is the hardest one.
- Double Jump sells best right after a hard world starts. Mention it in the loading screen and in the stage-30 banner.
- Try the Creator Hub's price testing tools once you have steady traffic, instead of guessing.
