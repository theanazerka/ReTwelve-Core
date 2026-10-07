# Layout of added feature screens — 0.13.6

Grouped cells now default to the bundled original Telegram top/middle/bottom/single artwork, including selected states. Cells that supply their own background retain it. This covers the new privacy, storage, account, group-management, invitation, contact, sticker-catalog and form screens that previously hid separators without installing the original row artwork.

Generic input forms now lay out labels and controls from the cell content bounds instead of the whole table width. Text rows use 62 points, switches measure their actual label width and expand when necessary, and multiline fields retain 112 points. The save button uses “Готово”; text fields have vertical centering and a clear button.

The armv7 package compiles. Visual review on physical devices remains necessary, particularly at 320-point width and with the iOS 6 keyboard. This change addresses shared layout defects; it is not a completed redesign of every feature.
