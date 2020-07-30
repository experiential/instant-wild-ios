# Instant Wild

This is the original Instant Wild app code that I developed between 2011-2014 or so.

There is a video [here](https://youtu.be/CmNCfBUZMNY) showing the app in action shortly before it was retired, though by this time a few bugs had appeared due to changes in iOS, and my employer could not afford to pay me to fix them! 

## Design

The app uses multi-threading to download from and update to the server while allowing the user to continue to use the UI smoothly. This requires a client-side data model held in memory and extensive use of the notifications system to update the UI as results/confirmations come back from the server and update the data model. The app performs its own image caching too (there were no major libraries or iOS functions around to handle this when I wrote the first version of the app).

## Performance

Although there was an initial rush of around 80,000 downloads when the first version of the app was launched, during its lifetime generally had a solid user-base of around 2000. It also had a rating of 4.5 stars on the App Store. The app was shown on BBC Click in 2016.
