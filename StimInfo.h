//
//  StimInfo.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 13/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StimInfo : NSObject{
    
    NSMutableDictionary *data;
}

-(void)readFromFile:(NSString*)fname;
@end
