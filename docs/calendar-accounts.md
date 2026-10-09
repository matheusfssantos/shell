# Calendar accounts

The custom Caelestia calendar supports multiple Google Calendar and Microsoft
Outlook/Microsoft 365 accounts. Account metadata stays in
`~/.config/caelestia/calendar-accounts.json`; OAuth tokens and the Google
desktop client secret are stored by Secret Service (`secret-tool`). None of
these values belong in Git.

Open the expanded calendar with `Super+F2`, select **Accounts**, and follow the
provider setup below. The calendar synchronizes automatically every five
minutes and can also be refreshed from its header.

## Google Calendar

1. Create or select a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com).
3. Configure the OAuth consent screen. While the app is in testing, add your
   Google accounts as test users.
4. Create an OAuth client with application type **Desktop app** and download
   its JSON file.
5. In Calendar → Accounts, enter the full path to that JSON file and select
   **Connect Google**. Finish consent in the browser.

The implementation uses Google's OAuth flow for installed applications with
PKCE and a temporary loopback redirect. It requests calendar access so events
can be read, created, edited, and deleted.

## Microsoft Outlook / Microsoft 365

1. In [Microsoft Entra app registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade), create an application.
2. Choose the supported account types you need. To support personal Outlook
   accounts too, include personal Microsoft accounts.
3. Under **Authentication**, enable public client flows.
4. Add delegated Microsoft Graph permissions `User.Read` and
   `Calendars.ReadWrite`.
5. Copy the **Application (client) ID** into Calendar → Accounts and select
   **Connect Microsoft**. Complete login in the browser. When Microsoft asks
   for a device code, Caelestia has already copied it to the clipboard.

An organization may require an administrator to approve `Calendars.ReadWrite`.

## Command line

The same operations are available without the UI:

```sh
./scripts/calendar-sync.py connect-google --credentials /path/to/client_secret.json
./scripts/calendar-sync.py connect-microsoft --client-id APPLICATION_ID
./scripts/calendar-sync.py sync
./scripts/calendar-sync.py status
```

Disconnecting an account removes its credentials from Secret Service. Local
events remain in `~/.local/state/caelestia/calendar-events.json`; the remote
event cache is `~/.local/state/caelestia/calendar-remote-events.json`.
