# Media fixes 0.12.57

- Music: always read embedded artwork when the audio is ready; larger covers replace thumbnails, later thumbnails cannot downgrade them. Decode embedded artwork to at most 640 pixels, so covers do not exhaust the old device's memory. Artwork quality still depends on the image included in the track.
- Video: ordinary video thumbnails and play action in chat, including album tiles. Asset videos are uploaded with documentAttributeVideo and without force_file; original-file sending remains available. Current uploader limit is 25 MB.
- Albums: photos and videos sharing grouped_id use one bubble and ordered tiles; each tile opens the matching media. Keep original message IDs for pagination and actions. Regroup after pages merge without duplicating captions.
- Replies: show author/quote above message content; resolve older target messages via messages.getMessages or channels.getMessages. Deleted/unavailable targets have an explicit placeholder.
- Picker: port local-asset portions of TGImagePickerCell.mm, TGImagePickerAsset.m, TGImagePickerCellCheckButton.m, TGImagePickerCheckButton.m and the complete TGImagePickerGalleryCell.m from Telegram iOS 1.1 (2013). Use the original grid dimensions, overlay Albums button, bottom panel, send/cancel buttons and animated selection/count controls. Selection persists across albums. Send selected assets sequentially in selection order. Adapted controller integrates AssetsLibrary and this client's uploader/search; original ActionStage and the original paging-gallery implementation are not transplanted. Preview uses this client's scroll view and swipe controls.

Source: /Users/anazerka/Downloads/telegram_iphone.src/TelegraphKit/TelegraphKit; original copyright Peter Iakovlev, 2013, GPL v2 or later. Image resources copied unchanged from Telegraph/Telegraph/Resources.

Verified: iOS 6 armv7 compilation/package; Foundation history tests cover pagination, album captions, ordering, repeated regrouping, local/remote replies and empty history. Camera roll, upload/playback and visual appearance require device verification; no device run claimed.
