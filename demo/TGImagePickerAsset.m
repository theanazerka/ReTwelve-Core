#import "TGImagePickerAsset.h"





@interface TGImagePickerAsset ()
{

}

@end

@implementation TGImagePickerAsset

@synthesize asset = _asset;
@synthesize assetUrl = _assetUrl;
@synthesize thumbnailImage = _thumbnailImage;
@synthesize isLoading = _isLoading;
@synthesize isLoaded = _isLoaded;

- (id)initWithAsset:(ALAsset *)asset
{
    self = [super init];
    if (self != nil)
    {
        
        
        _asset = asset;
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGImagePickerAsset *copyAsset = [[TGImagePickerAsset alloc] init];
    
    copyAsset.asset = _asset;
    copyAsset.assetUrl = _assetUrl;
    copyAsset.thumbnailImage = _thumbnailImage;
    copyAsset.isLoading = _isLoading;
    copyAsset.isLoaded = _isLoaded;
    
    return copyAsset;
}

- (void)setAsset:(ALAsset *)asset
{
    _asset = asset;
}

- (NSString *)assetUrl
{

    
    if (_assetUrl == nil && _asset != nil)
        _assetUrl = [[_asset.defaultRepresentation url] absoluteString];

    

    return _assetUrl;
}

- (void)load
{
    _thumbnailImage = [[UIImage alloc] initWithCGImage:[_asset thumbnail]];
    
    _isLoading = false;
    _isLoaded = true;
}

- (void)unload
{
    _thumbnailImage = nil;
    _isLoaded = false;
}

- (UIImage *)forceLoadedThumbnailImage
{
    if (_thumbnailImage != nil)
        return _thumbnailImage;
 
    if (_asset != nil)
        return [[UIImage alloc] initWithCGImage:[_asset thumbnail]];
    
    return nil;
}

@end
