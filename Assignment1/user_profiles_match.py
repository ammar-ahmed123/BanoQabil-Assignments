# Simple user profiles match
user1 = {
    "name": "Ali",
    "age": 25,
    "city": "karachi"
}

user2 = {
    "name": "Alina",
    "age": 27,
    "city": "karachi"
}

# Matching logic using if/else
if user1["city"] == user2["city"]:
    if abs(user1["age"] - user2["age"]) <= 5:
        print("Users match! They have the same city and similar age.")
    else:
        print("Users have the same city, but age difference is too large.")
elif abs(user1["age"] - user2["age"]) <= 5:
    print("Users have similar age, but different city.")
else:
    print("Users do not match.")
