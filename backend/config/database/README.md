# MongoDB Configuration

## Setup Instructions

1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Create a free cluster (M0 tier)
3. Create a database user with read/write access
4. Whitelist your IP (or use `0.0.0.0/0` for dev)
5. Get your connection string from **Connect → Drivers**
6. Set it in your `.env` file:

```
MONGO_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/trace?retryWrites=true&w=majority
```

## Database Name
The app uses database name: `trace`

## Collections
The following collections are auto-created by Mongoose:
- `users` — Registered users
- `drivers` — Driver profiles
- `cabrides` — Cab ride records
- `foodorders` — Food delivery orders
- `restaurants` — Restaurant listings
- `menuitems` — Menu items per restaurant
- `menucategories` — Menu category groupings
- `admins` — Admin accounts

## Seeding Data
To seed sample restaurants and menu items:
```bash
cd backend
node scripts/seedRestaurants.js
```
