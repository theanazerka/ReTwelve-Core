#import "Material/TGMaterialKit.h"
#import "TGLocationController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
@interface TGLocationController () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *manager;
@property (nonatomic, strong) MKMapView *map;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic) BOOL selectedPoint;
@end
@implementation TGLocationController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Местоположение";
    self.map = [[MKMapView alloc] initWithFrame:self.view.bounds]; self.map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [self.view addSubview:self.map];
    self.hint = [[UILabel alloc] init]; self.hint.backgroundColor = [UIColor colorWithWhite:1 alpha:.95]; self.hint.font = TGMaterialFont(14,NO); self.hint.textAlignment = NSTextAlignmentCenter; self.hint.numberOfLines = 2; self.hint.text = @"Определяем местоположение…\nИли удерживайте палец на нужной точке карты."; [self.view addSubview:self.hint];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отправить" style:UIBarButtonItemStyleDone target:self action:@selector(send)]; self.navigationItem.rightBarButtonItem.enabled = NO;
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectPoint:)]; [self.map addGestureRecognizer:press];
    self.manager = [[CLLocationManager alloc] init]; self.manager.delegate = self; self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    if ([self.manager respondsToSelector:@selector(requestWhenInUseAuthorization)]) [self.manager requestWhenInUseAuthorization];
    [self.manager startUpdatingLocation];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.hint.frame = CGRectMake(0, self.view.bounds.size.height - 54, self.view.bounds.size.width, 54); }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.manager stopUpdatingLocation]; }
- (void)useLocation:(CLLocation *)location {
    if (self.selectedPoint || location.horizontalAccuracy < 0 || fabs([location.timestamp timeIntervalSinceNow]) > 60) return;
    [self applyCoordinate:location.coordinate]; self.map.region = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000); [self.manager stopUpdatingLocation];
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations { [self useLocation:[locations lastObject]]; }
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation { [self useLocation:newLocation]; }
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error { self.hint.text = @"Местоположение недоступно.\nМожно выбрать точку удержанием на карте."; }
- (void)applyCoordinate:(CLLocationCoordinate2D)coordinate { self.coordinate = coordinate; self.navigationItem.rightBarButtonItem.enabled = YES; [self.map removeAnnotations:self.map.annotations]; MKPointAnnotation *pin = [[MKPointAnnotation alloc] init]; pin.coordinate = coordinate; [self.map addAnnotation:pin]; self.hint.text = [NSString stringWithFormat:@"%.5f, %.5f\nУдерживайте палец на карте, чтобы изменить точку.", coordinate.latitude, coordinate.longitude]; }
- (void)selectPoint:(UILongPressGestureRecognizer *)gesture { if (gesture.state != UIGestureRecognizerStateBegan) return; self.selectedPoint = YES; [self.manager stopUpdatingLocation]; [self applyCoordinate:[self.map convertPoint:[gesture locationInView:self.map] toCoordinateFromView:self.map]]; }
- (void)send { if (self.navigationItem.rightBarButtonItem.enabled && self.selection) { self.selection(self.coordinate.latitude, self.coordinate.longitude); [self.navigationController popViewControllerAnimated:YES]; } }
@end
