# SoulChoice — Final Spec Notes

## BÖLÜM 3: No Follow System

SoulChoice deliberately has NO follow/follower system.

**Rationale:** The app is built around invitation-driven connections. Users meet through specific, intentional invitations (davetler) rather than passive following. A follow system would create social pressure, popularity hierarchies, and reduce the intimacy of each individual connection.

**What exists instead:**
- **Favorites (⭐):** Private, one-directional bookmarking of interesting profiles. Not visible to the favorited user. Used as a personal "save for later" mechanism. Backed by the `favorites` table.
- **Match:** When an invitation owner selects an applicant (DecisionScreen), a match is created and a chat opens. This is the only "connection" in the system.
- **No public follower/following counts** on any profile screen.

**Profile screen CTA:**
- Own profile → "Profili Düzenle" button (navigates to profile setup)
- Other user's profile → "Gelmek isterim" gradient button (navigates back, user should apply from the invitation card)

## Architecture Decisions

- State: Flutter Riverpod (FutureProvider + StateProvider)
- Navigation: GoRouter 14.x with StatefulShellRoute (bottom nav)
- Backend: Supabase self-hosted on Hetzner
- Auth: Phone + OTP (autoconfirm for testing; Twilio integration pending)
- Push: Firebase Messaging (google-services.json pending)
