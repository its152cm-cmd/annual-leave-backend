# Annual Leave

**AI-assisted group trip planning: leave optimisation, collaborative decisions and automatic expense splitting.**

Team: **The Deployers**

| | |
|---|---|
| **Live app** | https://annual-leave-15b6e.web.app |
| **Backend API (docs)** | https://annual-leave-api-muoy.onrender.com/docs |
| **User guide** | https://canva.link/hu14nty8hg320ff |

---

## 1. What is Annual Leave?

Planning a trip with friends usually means chasing people in chat, comparing
hotels in a spreadsheet and resolving about who owes whom afterwards.
Annual Leave puts the whole journey in one app:

- **AI trip planning:** Gemini builds a day-by-day itinerary (attractions, food, hotels, flights) from your destination, dates, budget and tastes.
- **Leave optimisation:** suggests the best days off around public holidays so a few leave days become a longer break.
- **Group decisions:** a group chat where members share suggestions, vote on them, and the host finalises the plan in a Trip Summary.
- **Budget tracking:** per-category budget (Transport, Hotel, Food, Tickets, Other) with live "remaining" amounts.
- **Expense splitting:** scan a receipt, assign items to people and see who owes whom.

## 2. Tech stack

| Part | Technology |
|---|---|
| Frontend | Flutter Web (hosted on Firebase Hosting) |
| Backend | Python, FastAPI (hosted on Render) |
| Database / auth / storage | Supabase (PostgreSQL) |
| AI | Google Gemini (itinerary, receipt scanning, chat assistant) |
| Maps and places | Geoapify |
| Push notifications | Firebase Cloud Messaging |

## 3. How to test the app (Quick start / Refer to the User guide URL for more details)

### Quick start
1. Open **https://annual-leave-15b6e.web.app** (wait up to ~1 minute on first load).
2. Sign in with a test account, or sign up with your own email.

   | Role | Email | Password |
   |---|---|---|
   | Test user 1 | `FILL IN` | `FILL IN` |
   | Test user 2 | `FILL IN` | `FILL IN` |

   Use two browser windows (one normal, one incognito) to try the group features as two different people.

**A. Solo trip**
1. Home → **Create a new trip** → choose **Solo**.
2. Fill in **From**, **To** and **Dates** (all required; or tap *Suggest dates from my leave*), set a budget → **Next**.
3. Answer the travel-preference questions → the AI generates an itinerary (this can take 30–60 seconds; a loading indicator is shown).
4. Open the itinerary, switch Day / Map views, tap a place for details.

**B. Group trip**
1. Create a new trip → Group → add a collaborator (search by name or email) → Create group chat.
2. In the chat, open Trip Summary and fill in the destination.
3. Go to the Suggestions tab and heart the places you like (your Explore favourites also appear under the ♥ filter).
4. Share to group the favourite items. In real use this is for group discussion, and members can vote on them.
5. Select the other details (hotel, attractions and so on, which are all come from the voted items), or leave them blank, because the AI will suggest them.
6. The host generates the group itinerary.

**C. Expenses and budget**
1. Open the trip → **Splitting Cost**.
2. Scan or upload a receipt, choose its category (Food / Hotel / Tickets / Transport / Other), assign items and confirm the split.
3. See **Budget by category** (e.g. *Remaining RM 969 / RM 1,000*) and who owes whom.

## 4. Known limitations

- Free-tier hosting: first request after idle is slow (cold start).
- AI generation takes 30–60 seconds; the app shows a loading indicator meanwhile.