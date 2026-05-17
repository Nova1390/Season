# Google OAuth and Notifications

Last updated: 2026-05-17

## Scope

This branch prepares two product surfaces:

- Google OAuth as the shared identity foundation for the future Android app.
- A first in-app notification inbox behind the bell icon.

Staging remains untouched unless a dedicated release preflight is explicitly requested.

## Google OAuth

The iOS app now has a Google OAuth code path through Supabase Auth. The visible entry point is gated by `FeatureFlags.googleAuthenticationEnabled`:

- `DEBUG`: enabled so the flow can be tested once the provider is configured.
- `Release/TestFlight`: disabled until Google Cloud and Supabase provider settings are verified.

Required external configuration before enabling in TestFlight:

1. Create/configure Google OAuth clients for iOS, Android, and web/server usage.
2. Enable Google in Supabase Auth Providers for each environment.
3. Add the Supabase callback URL in Google Cloud: `https://<project-ref>.supabase.co/auth/v1/callback`.
4. Keep the app callback scheme available: `season://auth/callback`.
5. Test iOS sign-in on a real device and simulator before flipping the Release flag.

Android should reuse the same Supabase project/provider, with Android package/signing SHA settings added to the Google Cloud OAuth configuration.

## Notification Inbox V1

The bell is no longer a stub. It opens a local notification inbox generated from existing app state:

- Seasonal reminder: highlights the current strongest seasonal ingredient and links to Today.
- Shopping list reminder: appears when the user has pending shopping list items.
- Fridge reminder: appears when the fridge is empty or has very few ingredients.

These notifications are intentionally local and deterministic:

- No APNs/FCM token is requested yet.
- No backend notification table is required yet.
- Read state is local via `UserDefaults`.

## Future V2

When Season needs server-driven or cross-device notifications:

1. Add a `user_notifications` table with explicit grants and RLS policies.
2. Write notifications from trusted backend jobs only.
3. Keep the iOS inbox as the consumer surface.
4. Add APNs for iOS and FCM for Android only after message taxonomy, opt-in copy, and unsubscribe rules are settled.

Any new Supabase table must include explicit grants because Supabase is changing default Data API exposure behavior in 2026.
