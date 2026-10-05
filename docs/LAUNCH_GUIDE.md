# Launch and growth guide

Code gets you a working game. Players and money come from how you present it, promote it and keep improving it.
This guide is a practical plan for that part.

## 1. Make it look like a hit before launch

Every pet already has a generated 3D model, and the world has terrain, weather and lighting per zone. Custom art is still the biggest upgrade you can make.

1. **Pet models.** Make or commission models for the pets, starting with Legendary and Mythic. Put each Model in `ReplicatedStorage > PetModels` with the exact pet name. No code changes are needed. To tweak a generated pet instead, edit its colours and extras in `src/Shared/PetStyles.lua`.
2. **Icon (512x512).** One cute, high-contrast pet on a bright background, with no small text. This is what players see in search and on the home page.
3. **Thumbnails (1920x1080).** Show the most exciting moment: a Mythic hatch, a huge pet army, or a giant coin number. Add a few big words such as "NEW!" or "UPDATE 1".
4. **Title.** Lead with the genre and add an update tag later, for example `Hatch Legends [UPDATE 1]`.
5. **Description.** Write two short lines about the game, then list the active codes. Players search for codes.
6. **Sounds.** Collect, hatch and rare-hatch sounds make the game feel far more rewarding. Add them in `Config.Sounds`.

## 2. Launch week

1. Publish, make the experience **public**, and fill out the Maturity & Compliance questionnaire.
2. Create a **Roblox group** and set `Config.GroupId`. The group bonus turns visitors into members you can announce updates to.
3. Post a launch code such as `RELEASE` on TikTok, YouTube Shorts and in your group.
4. Run a small **Roblox Ads Manager** campaign. Even a modest budget brings the first wave of players, and Roblox's recommendation system needs that wave to judge your game.
5. Play in your own servers during launch week. Answer questions and fix anything players get stuck on.

## 3. Watch the numbers that matter

Open your experience's **Analytics** on the Creator Hub. Roblox recommends games largely based on how players behave once they join.

| Metric | What it tells you | How this game helps |
|---|---|---|
| **Day 1 retention** | Do players come back tomorrow? | Daily streak with an exclusive pet on day 7 |
| **Session length** | Do players stay? | Playtime gifts up to 60 minutes, goal bar, egg odds |
| **Payer conversion** | Do players buy anything? | Cheap first purchase, upsells in the egg menu |
| **Thumbnail click rate** | Do people who see the game click it? | Only your icon and thumbnails can fix this |

If players leave quickly, the start is too slow or confusing. Lower the first egg's cost or raise zone 1's orb value.
If players stall later on, look for the zone or rebirth step where they stop and make it cheaper.

## 4. Update rhythm

Successful simulators update every one to two weeks. Each update is a reason for old players to come back.

- **Easy update:** add a new egg with new pets to an existing zone. It takes a few lines in `Config.lua`.
- **Medium update:** add a new zone at the end of `Config.Zones`. The map, gate, bridge and orbs build themselves.
- **Event update:** hand out a limited code and a limited-time egg for a holiday, then remove the egg afterwards.
- Put the update number in the title and thumbnail, and post a new code with every update.

## 5. Ideas for later

- **Trading** between players. It is a big engagement driver, but it is complex and needs careful anti-scam design.
- **Pet levels** on top of Golden and Rainbow crafting, so favourite pets keep growing.
- **More events**, such as a Luck Hour or a limited event egg, added to `Config.Events`.
- **Badges** for milestones. They show up on player profiles and work as free advertising.
- **Private servers.** Turn them on in the experience settings and set a price for an extra income stream.

## 6. How the money works

- When players buy your gamepasses and developer products, **you keep 70% of the Robux** and Roblox keeps 30%.
- **Premium Payouts** pay you extra Robux based on how long Roblox Premium members spend in your game, with no purchases needed.
- **Developer Exchange (DevEx)** turns earned Robux into real money. As of late 2025 it requires at least **30,000 earned Robux**, age **13 or older**, and a **verified email**. The standard rate is **$0.0038 per Robux**, about $114 per 30,000 Robux. These terms change, so check the [official DevEx page](https://create.roblox.com/docs/production/monetization/developer-exchange) before you plan around them.
- If you are under 18, a parent or guardian will need to help with DevEx and tax forms.

## 7. Be realistic

Thousands of experiences launch every week, and most get only a handful of players.
The games that break out usually combine polished art, a thumbnail people want to click, fast early progress, and frequent updates.
Treat launch as the start: watch the analytics, listen to players, and keep shipping updates.
