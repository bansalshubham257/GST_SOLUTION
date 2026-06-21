# Session Summary — GST Solution

## Goal
Deliver a stable, offline-first GST billing app with chat assistant, stock/expiry tracking, business templates, and ad-supported free plan — ready for Play Store.

## Constraints & Preferences
- API base URL: `https://gstsolution-production.up.railway.app/api/v1` (production)
- Android device KB2001 (currently connected)
- Debug builds with `flutter build apk --debug`
- Riverpod + Hive; Dio for API calls; `flutter_chat_ui 1.6.15`
- Discount applies to **subTotal only** (excludes GST)
- On free/local_paid plans: zero network calls after initial login; app loads entirely from local Hive cache
- Income tax estimated at **10%** of net profit before tax (hardcoded)
- Free plan = unlimited features + ads; local_paid/db_paid = no ads
- WhatsApp `+919538923091` for upgrade/payment discussions (no in-app payment integration)
- App display name: "Business Solution"; package name unchanged

## Progress
### Done
- **Purchase Register card**: Added to GST Reports page quick reports section (navigates to existing purchase-register route)
- **AdBannerWidget on Dashboard**: Added at bottom of scrollable body (before 80px spacer)
- **AdBannerWidget on GST Reports page**: Added at bottom (below quick reports cards)
- **Build succeeded**: `app-debug.apk` built and installed on KB2001

### In Progress
- (none)

### Blocked
- (none)

## Key Decisions
- Banner ads placed at bottom of key scrollable pages (Dashboard, GST Reports)
- All ad widgets use non-const instantiation to avoid "Not a constant expression" error with ConsumerStatefulWidget

## Next Steps
1. Test the installed app on device for crash/behavior
2. Add `AdBannerWidget` to more pages (Item Catalog, Purchase List, Customer List)
3. Add video ad triggers for export features (backup, GST reports, sales register)
4. Replace test AdMob unit IDs with real IDs
5. Test full offline flow: login once → restore backup → re-launch without internet
