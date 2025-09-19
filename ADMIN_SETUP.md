# Admin Setup Guide

## Overview
This guide explains how to set up and use the devotional admin functionality in Alkitab 2.0.

## Superadmin Setup

### Automatic Setup
The superadmin account (`heary@hopetv.asia`) is automatically configured when:
1. The user with email `heary@hopetv.asia` logs into the app
2. The app initializes the admin service during startup

### Manual Verification
To verify superadmin access:
1. Log in with `heary@hopetv.asia`
2. Go to Profile tab
3. You should see "Devotional Admin (Super)" button

## Admin Features

### Devotional Management
- **Create**: Add new devotionals with title, content, reflection questions, prayers
- **Edit**: Modify existing devotionals
- **Delete**: Remove devotionals (with confirmation)
- **View Stats**: See total devotionals and monthly counts

### Access Control
- **Superadmin**: `heary@hopetv.asia` (hardcoded)
  - Can manage all devotionals
  - Can assign admin roles to other users
  - Has full administrative privileges

- **Admin**: Users assigned by superadmin
  - Can manage devotionals
  - Cannot assign roles to other users

### Navigation
- Admin panel accessible via Profile tab → "Devotional Admin" button
- Direct route: `/admin/devotionals`

## Firebase Security Rules

### Firestore Rules
The `firestore.rules` file contains security rules that:
- Allow only admins to modify devotionals
- Allow users to read devotionals
- Protect user data (bookmarks, notes, profiles)
- Restrict admin role management to superadmin only

### Deployment
To deploy the security rules:
```bash
firebase deploy --only firestore:rules
```

## Database Collections

### user_roles
```json
{
  "userId": {
    "role": "admin|superadmin",
    "email": "user@example.com",
    "created_at": "timestamp",
    "updated_at": "timestamp",
    "updated_by": "superadmin_uid"
  }
}
```

### devotionals
```json
{
  "devotionalId": {
    "id": "unique_id",
    "title": "Devotional Title",
    "verse_reference": "John 3:16",
    "verse_text": "Bible verse text",
    "content": "Devotional content",
    "reflection_questions": ["Question 1", "Question 2"],
    "prayer": "Prayer text",
    "date": "2024-01-01T00:00:00.000Z",
    "author": "Author Name",
    "image_url": "optional_image_url"
  }
}
```

## Required Indexes

### user_bookmarks Collection
Create these composite indexes in Firebase Console:

1. **Bible Bookmarks Index**:
   - Collection: `user_bookmarks`
   - Fields: `type` (Ascending), `user_id` (Ascending), `created_at` (Descending), `__name__` (Descending)

2. **Devotional Bookmarks Index**:
   - Collection: `user_bookmarks`
   - Fields: `type` (Ascending), `user_id` (Ascending), `created_at` (Descending), `__name__` (Descending)

## Troubleshooting

### Admin Button Not Showing
1. Verify the user is logged in with correct email
2. Check if admin role is properly set in Firestore
3. Restart the app to refresh admin status

### Access Denied Errors
1. Verify Firebase security rules are deployed
2. Check user authentication status
3. Confirm admin role assignment in `user_roles` collection

### Index Errors
1. Create required composite indexes in Firebase Console
2. Wait for indexes to build (can take several minutes)
3. Test bookmark functionality after completion

## Development Notes

### Adding New Admin Users
Only the superadmin can assign admin roles. This should be done programmatically or through the Firebase Console by adding documents to the `user_roles` collection.

### Testing Admin Functionality
1. Create a test Firebase project
2. Deploy security rules
3. Test with the superadmin email
4. Verify CRUD operations work correctly

### Production Considerations
- Never hardcode emails in production (consider environment variables)
- Implement proper logging instead of print statements
- Add comprehensive error handling
- Consider implementing audit logs for admin actions