@import UIKit;
@import ObjectiveC.runtime;

@interface UISystemNavigationAction : NSObject
	@property(nonatomic, readonly, nonnull) NSArray<NSNumber*>* destinations;
	-(BOOL)sendResponseForDestination:(NSUInteger)destination;
@end

@implementation UIApplication(GoBack)

//Derived from https://stackoverflow.com/a/43102093
- (BOOL)goBackToPreviousAppIfAvailable{
    Ivar sysNavIvar = class_getInstanceVariable(UIApplication.class, "_systemNavigationAction");
    UIApplication* app = UIApplication.sharedApplication;
	UISystemNavigationAction* action = object_getIvar(app, sysNavIvar);
	if (action) {
		NSUInteger destination = action.destinations.firstObject.unsignedIntegerValue;
		return [action sendResponseForDestination:destination];
	} else {
		return NO;
	}
}

@end