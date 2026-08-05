# StudySphere AI Development Rules (MANDATORY)

> These rules are mandatory for every AI task. Never ignore them.

## 1. Scope Control

-   Modify only the files required for the requested task.
-   Never edit unrelated modules.
-   If additional files are needed, stop and ask for confirmation first.

## 2. Never Remove Existing Features

-   Never delete, disable, or replace existing features unless
    explicitly instructed.
-   Existing working features must continue working after every change.

## 3. Preserve Functionality

Verify after every change: - Authentication - Notes - Downloads /
Offline PDFs - Community - AI Chat - Profile - Follow / Followers /
Following - Bookmarks - Notifications

## 4. No Dummy Data

-   Never hardcode sample values.
-   Always load user data from the database.
-   Never replace BCA with B.Tech or any default course.

## 5. Offline Support

-   Never access Cloudinary when a file is already downloaded.
-   Open local files while offline.
-   Detect internet connectivity.
-   Show a friendly 'No Internet Connection' screen instead of raw
    exceptions.

## 6. Error Handling

Never expose raw exceptions or stack traces to users.

## 7. UI Consistency

-   Follow the existing StudySphere design system.
-   Do not redesign screens unless requested.

## 8. Startup

-   Never increase splash duration.
-   Never add artificial delays.

## 9. Before Coding

Always list: 1. Files to be modified. 2. Why each file will change. 3.
Expected impact.

## 10. After Coding

Always provide: - Files changed. - Summary. - Risks. - Manual testing
checklist.

## 11. Git Safety

-   One feature = one commit.
-   Never mix unrelated changes.

## 12. Code Quality

-   Reuse existing components.
-   Avoid duplicate code.
-   Follow project architecture.

## 13. Safety Rule

If a change may break another feature: - Stop. - Explain the risk. - Ask
for confirmation.

## 14. Registration

-   Terms & Conditions checkbox must be mandatory.

## 15. Final Checklist

-   No compile errors.
-   No broken features.
-   Offline works.
-   Online works.
-   Correct profile data.
-   No missing assets.
-   No broken routes.




## Golden Rule

If you are not 100% sure a change will not break another feature, do not
modify it. Explain the risk and ask for confirmation first.
