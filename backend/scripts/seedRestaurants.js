// seedRestaurants.js - Run this file once to populate your database with 200 restaurants
const mongoose = require('mongoose');
require('dotenv').config();

// Models
const Restaurant = require('./models/Restaurant');
const MenuCategory = require('./models/MenuCategory');
const MenuItem = require('./models/MenuItem');

const MONGO_URI = process.env.MONGO_URI;

// Mumbai coordinates center: 19.0760, 72.8777
function getRandomMumbaiCoordinates() {
  const centerLat = 19.0760;
  const centerLon = 72.8777;
  
  // 10km radius (0.09 degrees ≈ 10km)
  const radiusInDegrees = 0.09;
  
  const lat = centerLat + (Math.random() - 0.5) * 2 * radiusInDegrees;
  const lon = centerLon + (Math.random() - 0.5) * 2 * radiusInDegrees;
  
  return { lat, lon };
}

const mumbaiAreas = [
  'Andheri West', 'Andheri East', 'Bandra West', 'Bandra East', 'Juhu',
  'Powai', 'Worli', 'Lower Parel', 'Dadar', 'Kurla', 'Ghatkopar',
  'Mulund', 'Thane', 'Borivali', 'Kandivali', 'Malad', 'Goregaon',
  'Vile Parle', 'Santa Cruz', 'Khar', 'Santacruz', 'Versova',
  'Lokhandwala', 'Oshiwara', 'Jogeshwari', 'Vikhroli', 'Bhandup',
  'Chembur', 'Wadala', 'Sion', 'Matunga', 'Mahim', 'Prabhadevi',
];

const restaurantTemplates = [
  {
    namePrefix: 'Spice Garden',
    description: 'Authentic Indian cuisine with traditional spices and flavors',
    cuisines: ['Indian', 'North Indian', 'Punjabi'],
    coverImage: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800',
    isVegOnly: false,
    discount: 20,
  },
  {
    namePrefix: 'Pizza Paradise',
    description: 'Wood-fired pizzas with fresh Italian ingredients',
    cuisines: ['Italian', 'Pizza', 'Fast Food'],
    coverImage: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800',
    isVegOnly: false,
    discount: 25,
  },
  {
    namePrefix: 'Burger Junction',
    description: 'Gourmet burgers and loaded fries',
    cuisines: ['American', 'Fast Food', 'Burgers'],
    coverImage: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800',
    isVegOnly: false,
    discount: 15,
  },
  {
    namePrefix: 'Biryani House',
    description: 'Aromatic biryanis prepared with authentic Hyderabadi spices',
    cuisines: ['Indian', 'Biryani', 'Mughlai'],
    coverImage: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800',
    isVegOnly: false,
    discount: 20,
  },
  {
    namePrefix: 'Dosa Express',
    description: 'South Indian specialties - crispy dosas and filter coffee',
    cuisines: ['South Indian', 'Dosa', 'Breakfast'],
    coverImage: 'https://images.unsplash.com/photo-1694674362867-0f32e54d1ab7?w=800',
    isVegOnly: true,
    discount: 10,
  },
  {
    namePrefix: 'Chinese Dragon',
    description: 'Indo-Chinese fusion with bold flavors',
    cuisines: ['Chinese', 'Asian', 'Fast Food'],
    coverImage: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=800',
    isVegOnly: false,
    discount: 18,
  },
  {
    namePrefix: 'Tandoor King',
    description: 'Tandoori specialties and kebabs',
    cuisines: ['North Indian', 'Tandoor', 'Kebab'],
    coverImage: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800',
    isVegOnly: false,
    discount: 22,
  },
  {
    namePrefix: 'Veg Delight',
    description: 'Pure vegetarian restaurant with diverse menu',
    cuisines: ['Indian', 'North Indian', 'South Indian'],
    coverImage: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800',
    isVegOnly: true,
    discount: 12,
  },
  {
    namePrefix: 'Cafe Culture',
    description: 'Cozy cafe with coffee, sandwiches and desserts',
    cuisines: ['Cafe', 'Beverages', 'Snacks'],
    coverImage: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
    isVegOnly: true,
    discount: 15,
  },
  {
    namePrefix: 'Street Bites',
    description: 'Mumbai street food favorites',
    cuisines: ['Street Food', 'Chaat', 'Fast Food'],
    coverImage: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800',
    isVegOnly: true,
    discount: 10,
  },
];

const menuItemTemplates = {
  'Indian': [
    { name: 'Paneer Butter Masala', desc: 'Cottage cheese in rich tomato gravy', price: 220, isVeg: true, tags: ['bestseller'] },
    { name: 'Butter Chicken', desc: 'Tender chicken in creamy tomato sauce', price: 280, isVeg: false, tags: ['bestseller'] },
    { name: 'Dal Makhani', desc: 'Black lentils cooked overnight with butter', price: 180, isVeg: true, tags: [] },
    { name: 'Palak Paneer', desc: 'Cottage cheese in spinach gravy', price: 200, isVeg: true, tags: [] },
    { name: 'Chicken Tikka Masala', desc: 'Grilled chicken in spicy curry', price: 290, isVeg: false, tags: ['bestseller'] },
    { name: 'Veg Korma', desc: 'Mixed vegetables in creamy cashew gravy', price: 190, isVeg: true, tags: [] },
  ],
  'Pizza': [
    { name: 'Margherita Pizza', desc: 'Classic tomato, mozzarella and basil', price: 249, isVeg: true, tags: ['bestseller'] },
    { name: 'Pepperoni Pizza', desc: 'Loaded with pepperoni and cheese', price: 349, isVeg: false, tags: [] },
    { name: 'Farmhouse Pizza', desc: 'Veggies and cheese on crispy base', price: 299, isVeg: true, tags: [] },
    { name: 'BBQ Chicken Pizza', desc: 'BBQ chicken with onions and peppers', price: 379, isVeg: false, tags: ['bestseller'] },
    { name: 'Paneer Tikka Pizza', desc: 'Indian fusion with paneer tikka', price: 329, isVeg: true, tags: [] },
  ],
  'Burgers': [
    { name: 'Classic Cheese Burger', desc: 'Beef patty with cheese and veggies', price: 199, isVeg: false, tags: ['bestseller'] },
    { name: 'Veg Supreme Burger', desc: 'Crispy veg patty with special sauce', price: 149, isVeg: true, tags: [] },
    { name: 'Chicken Burger', desc: 'Grilled chicken with mayo', price: 179, isVeg: false, tags: [] },
    { name: 'Double Decker Burger', desc: 'Two patties with extra cheese', price: 249, isVeg: false, tags: ['bestseller'] },
    { name: 'Paneer Burger', desc: 'Spiced paneer patty with mint chutney', price: 159, isVeg: true, tags: [] },
  ],
  'Biryani': [
    { name: 'Chicken Biryani', desc: 'Aromatic rice with tender chicken', price: 299, isVeg: false, tags: ['bestseller'] },
    { name: 'Mutton Biryani', desc: 'Slow-cooked mutton with basmati rice', price: 349, isVeg: false, tags: ['bestseller'] },
    { name: 'Veg Biryani', desc: 'Mixed vegetables with fragrant rice', price: 199, isVeg: true, tags: [] },
    { name: 'Egg Biryani', desc: 'Boiled eggs in spiced rice', price: 179, isVeg: false, tags: [] },
    { name: 'Paneer Biryani', desc: 'Cottage cheese biryani', price: 229, isVeg: true, tags: [] },
  ],
  'South Indian': [
    { name: 'Masala Dosa', desc: 'Crispy dosa with potato filling', price: 120, isVeg: true, tags: ['bestseller'] },
    { name: 'Idli Sambar', desc: 'Steamed rice cakes with lentil curry', price: 80, isVeg: true, tags: [] },
    { name: 'Medu Vada', desc: 'Crispy lentil donuts', price: 90, isVeg: true, tags: [] },
    { name: 'Rava Dosa', desc: 'Crispy semolina crepe', price: 110, isVeg: true, tags: [] },
    { name: 'Uttapam', desc: 'Thick pancake with toppings', price: 130, isVeg: true, tags: [] },
  ],
  'Chinese': [
    { name: 'Veg Hakka Noodles', desc: 'Stir-fried noodles with vegetables', price: 150, isVeg: true, tags: ['bestseller'] },
    { name: 'Chicken Fried Rice', desc: 'Fried rice with chicken and veggies', price: 180, isVeg: false, tags: [] },
    { name: 'Veg Manchurian', desc: 'Fried veggie balls in spicy sauce', price: 160, isVeg: true, tags: [] },
    { name: 'Chilli Chicken', desc: 'Spicy chicken with peppers', price: 220, isVeg: false, tags: ['bestseller'] },
    { name: 'Spring Rolls', desc: 'Crispy vegetable rolls', price: 120, isVeg: true, tags: [] },
  ],
};

const categories = ['Starters', 'Main Course', 'Breads', 'Rice', 'Desserts', 'Beverages'];

function getItemsForCuisine(cuisine, isVegOnly) {
  let items = menuItemTemplates[cuisine] || menuItemTemplates['Indian'];
  if (isVegOnly) {
    items = items.filter(item => item.isVeg);
  }
  return items;
}

const seedData = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('✅ Connected to MongoDB');

    // Clear existing data
    await Restaurant.deleteMany({});
    await MenuCategory.deleteMany({});
    await MenuItem.deleteMany({});
    console.log('🗑️  Cleared existing data');

    let restaurantCount = 0;
    let categoryCount = 0;
    let menuItemCount = 0;

    // Create 200 restaurants
    for (let i = 0; i < 200; i++) {
      const template = restaurantTemplates[i % restaurantTemplates.length];
      const coords = getRandomMumbaiCoordinates();
      const area = mumbaiAreas[Math.floor(Math.random() * mumbaiAreas.length)];
      const suffix = Math.floor(i / restaurantTemplates.length) > 0 ? ` ${Math.floor(i / restaurantTemplates.length) + 1}` : '';
      
      const restaurant = await Restaurant.create({
        name: `${template.namePrefix}${suffix}`,
        description: template.description,
        coverImageUrl: template.coverImage,
        logoImageUrl: `https://ui-avatars.com/api/?name=${encodeURIComponent(template.namePrefix)}&background=random`,
        location: {
          lat: coords.lat,
          lon: coords.lon,
          address: `${Math.floor(Math.random() * 500) + 1}, ${area}, Mumbai`,
        },
        cuisines: template.cuisines,
        avgRating: parseFloat((3.5 + Math.random() * 1.5).toFixed(1)),
        totalRatings: Math.floor(Math.random() * 2000) + 100,
        isVegOnly: template.isVegOnly,
        deliveryRadiusKm: Math.floor(Math.random() * 5) + 5,
        preparationTimeMin: Math.floor(Math.random() * 20) + 20,
        discount: template.discount,
      });

      restaurantCount++;

      // Create 3-4 categories per restaurant
      const numCategories = Math.floor(Math.random() * 2) + 3;
      const selectedCategories = categories.slice(0, numCategories);

      for (let j = 0; j < selectedCategories.length; j++) {
        const category = await MenuCategory.create({
          restaurantId: restaurant._id,
          name: selectedCategories[j],
          displayOrder: j + 1,
        });

        categoryCount++;

        // Get menu items based on cuisine
        const mainCuisine = template.cuisines[0];
        const availableItems = getItemsForCuisine(mainCuisine, template.isVegOnly);
        
        // Create 4-6 items per category
        const numItems = Math.floor(Math.random() * 3) + 4;
        for (let k = 0; k < numItems && k < availableItems.length; k++) {
          const itemTemplate = availableItems[k];
          
          await MenuItem.create({
            restaurantId: restaurant._id,
            categoryId: category._id,
            category: selectedCategories[j],
            name: itemTemplate.name,
            description: itemTemplate.desc,
            price: itemTemplate.price + Math.floor(Math.random() * 50) - 25, // Random variation
            imageUrl: `https://images.unsplash.com/photo-${1546069901000 + Math.floor(Math.random() * 100000000)}?w=400`,
            isVeg: itemTemplate.isVeg,
            tags: itemTemplate.tags,
            rating: parseFloat((3.8 + Math.random() * 1.2).toFixed(1)),
            ordersCount: Math.floor(Math.random() * 500),
          });

          menuItemCount++;
        }
      }

      // Progress indicator
      if ((i + 1) % 20 === 0) {
        console.log(`📦 Created ${i + 1}/200 restaurants...`);
      }
    }

    console.log('\n✅ Seed data created successfully!');
    console.log('\n📊 Summary:');
    console.log(`  - ${restaurantCount} restaurants`);
    console.log(`  - ${categoryCount} categories`);
    console.log(`  - ${menuItemCount} menu items`);
    console.log(`\n🌍 All restaurants are spread across Mumbai`);
    console.log(`📍 Coverage area: ~10km radius from Mumbai center`);
    
    mongoose.connection.close();
    console.log('\n🔌 Database connection closed');
  } catch (err) {
    console.error('❌ Seed Error:', err);
    process.exit(1);
  }
};

seedData();