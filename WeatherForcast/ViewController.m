//
//  ViewController.m
//  WeatherForcast
//
//  Created by badupro on 11/7/17.
//  Copyright © 2017 badupro. All rights reserved.
//

#import "ViewController.h"

#define FORCAST_URL    @"http://climatedataapi.worldbank.org/climateweb/rest/v1/country/mavg/bccr_bcm2_0/a2/tas/2020/2039/"
#define SUPPORT_URL    @"https://datahelpdesk.worldbank.org/knowledgebase/articles/902061-climate-data-api"

//country code
//https://unstats.un.org/unsd/methodology/m49/

#define CHART_ELEMENT   12345

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *countryCodeField;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self getData];
}

- (void)getData
{
    //get country code from text field
    NSString* countryCode = self.countryCodeField.text;
    NSLog(@"code: %@", countryCode);
    
    NSString *urlStr = [NSString stringWithFormat:@"%@%@", FORCAST_URL, countryCode];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"data request callback...");
        
        //check network error
        if (error) {
            NSLog(@"couldn't finish request: %@", error);
            return;
        }
        
        //check http error
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*)response;
        if (httpResp.statusCode < 200 || httpResp.statusCode >= 300) {
            NSLog(@"http error: %ld", (long)httpResp.statusCode);
            return;
        }
        
        //check json parse error
        NSError *parseErr;
        NSArray* pkg = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parseErr];
        if (!pkg || parseErr) {
            NSLog(@"parse json error: %@", parseErr);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onRequested:pkg];
        });
        
    }] resume];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) onRequested: (NSArray*) result
{
    NSLog(@"Enter: %s", __FUNCTION__);
    
    NSDictionary* dict = result[0];
    
    NSArray* temps = dict[@"monthVals"];
    NSLog(@"temps is: %@", temps);
    
    [self drawChart:temps];
}

- (void) drawChart: (NSArray*) result
{
    NSLog(@"Enter: %s", __FUNCTION__);
    
    NSMutableArray* data = [NSMutableArray array];
    [data addObject:[NSNumber numberWithFloat:1.0f]];
    [data addObject:[NSNumber numberWithFloat:2.0f]];
    [data addObject:[NSNumber numberWithFloat:3.0f]];

    //get maximum degree
    float maxDegree = [result[0] floatValue];
    float minDegree = [result[0] floatValue];

    for (int i = 1; i < [result count]; ++i) {
        float d = [result[i] floatValue];
        if (d < minDegree) {
            minDegree = d;
        }

        if (d > maxDegree) {
            maxDegree = d;
        }
    }
    
    float deltaD = (maxDegree - minDegree) / 9.0f;
    NSLog(@"delta d: %f", deltaD);

    //device size
    float w = self.view.frame.size.width;
    float h = self.view.frame.size.height;
    NSLog(@"w = %f, h = %f", w, h);
    
    //Bezier path for ploting graph
    UIBezierPath* _graphPath = [[UIBezierPath alloc]init];
    [_graphPath setLineWidth:10];
    
    //CAShapeLayer for graph allocation
    _graphLayout = [CAShapeLayer layer];
    _graphLayout.frame = CGRectMake(self.view.frame.size.width * 0, 0, self.view.frame.size.width*0.8, (self.view.frame.size.height*0.9));
    _graphLayout.fillColor = [UIColor clearColor].CGColor;
    _graphLayout.strokeColor = [UIColor blueColor].CGColor;
    _graphLayout.lineWidth = 2;
    _graphLayout.path = [_graphPath CGPath];
    _graphLayout.lineCap = @"round";
    _graphLayout.lineJoin = @"round";
    [self.view.layer addSublayer:_graphLayout];
    
    //draw ox line
    [_graphPath moveToPoint:CGPointMake(30, h - 100)];
    [_graphPath addLineToPoint:CGPointMake(w - 10, h - 100)];
    
    //draw oy line
    [_graphPath moveToPoint:CGPointMake(30, h - 100)];
    [_graphPath addLineToPoint:CGPointMake(30, 100)];
    
    float dx = (w - 40) / 13.0f;
    float x = 30 + dx;
    float dy = (h - 100 - 10) / 12.0f;
    float y = h - 100 - dy;
    
    //draw 12 month
    for (int i = 0; i < 12; ++i) {
        UILabel* monthLb = [[UILabel alloc] init];
        monthLb.text = [NSString stringWithFormat:@"%d", i + 1];
        monthLb.textColor = [UIColor blackColor];
        monthLb.frame = CGRectMake(x, h - 140, 100, 100);
        monthLb.tag = CHART_ELEMENT;
        [self.view addSubview:monthLb];
        monthLb.font = [UIFont systemFontOfSize:11];
        
        x += dx;
    }
    
    //draw 10 degree
    for (int i = 0; i < 10; ++i) {
        float d = minDegree + (i * deltaD);
        //draw min
        UILabel* tempLb = [[UILabel alloc] init];
        tempLb.text = [NSString stringWithFormat:@"%.1f", d];
        tempLb.textColor = [UIColor blackColor];
        tempLb.frame = CGRectMake(2, y, 30, 9);
        tempLb.tag = CHART_ELEMENT;
        [self.view addSubview:tempLb];
        tempLb.font = [UIFont systemFontOfSize:11];
        
        y -= dy;
    }
    
    x = 30 + dx;
    float y0 = h - 100 - dy;
    
    //draw 12 month degree
    for (int i = 0; i < 12; ++i) {
        float d = [result[i] floatValue];
        
        float t = (d - minDegree);
        y = y0 - (t / deltaD) * dy;
        
        //draw point
        UIView* rect = [[UIView alloc] initWithFrame:CGRectMake(x - 5, y - 5, 10, 10)];
        rect.backgroundColor = [UIColor yellowColor];
        rect.tag = CHART_ELEMENT;
        [self.view addSubview:rect];

        if (i == 0) {
            [_graphPath moveToPoint:CGPointMake(x, y)];
        }
        else {
            [_graphPath addLineToPoint:CGPointMake(x, y)];
        }

        x += dx;
    }
    
    _graphLayout.path = [_graphPath CGPath];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (IBAction)onRefresh:(id)sender {
    NSLog(@"Enter: %s", __FUNCTION__);
    
    [self.countryCodeField resignFirstResponder];
    
    while ([self.view viewWithTag:CHART_ELEMENT]) {
        [[self.view viewWithTag:CHART_ELEMENT] removeFromSuperview];
    }
    
    [_graphLayout removeFromSuperlayer];
    
    [self getData];
}


@end
