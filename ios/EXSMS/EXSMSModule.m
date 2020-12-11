// Copyright © 2018 650 Industries. All rights reserved.
#import <MessageUI/MessageUI.h>
#import <Messages/Messages.h>
#import <EXSMS/EXSMSModule.h>
#import <UMCore/UMUtilities.h>
#import <UMPermissionsInterface/UMPermissionsInterface.h>
@interface EXSMSModule () <MFMessageComposeViewControllerDelegate>
@property (nonatomic, weak) id<UMPermissionsInterface> permissionsManager;
@property (nonatomic, weak) id<UMUtilitiesInterface> utils;
@property (nonatomic, strong) UMPromiseResolveBlock resolve;
@property (nonatomic, strong) UMPromiseRejectBlock reject;
@end
@implementation EXSMSModule
UM_EXPORT_MODULE(ExpoSMS);

- (dispatch_queue_t)methodQueue
{
  // Everything in this module uses `MFMessageComposeViewController` which is a subclass of UIViewController,
  // so everything should be called from main thread.
  return dispatch_get_main_queue();
}

- (void)setModuleRegistry:(UMModuleRegistry *)moduleRegistry
{
  _permissionsManager = [moduleRegistry getModuleImplementingProtocol:@protocol(UMPermissionsInterface)];
  _utils = [moduleRegistry getModuleImplementingProtocol:@protocol(UMUtilitiesInterface)];
}


UM_EXPORT_METHOD_AS(isAvailableAsync,
                    isAvailable:(UMPromiseResolveBlock)resolve
                       rejecter:(UMPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    BOOL canOpenURL = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"sms:"]];
    resolve(@(canOpenURL));
  });
}
UM_EXPORT_METHOD_AS(sendSMSAsync,
                    sendSMS:(NSArray<NSString *> *)addresses
                    message:(NSString *)message
                   resolver:(UMPromiseResolveBlock)resolve
                   rejecter:(UMPromiseRejectBlock)reject)
{
  if (![MFMessageComposeViewController canSendText]) {
    reject(@"E_SMS_UNAVAILABLE", @"SMS service not available", nil);
    return;
  }
  if (_resolve != nil || _reject != nil) {
    reject(@"E_SMS_SENDING_IN_PROGRESS", @"Different SMS sending in progress. Await the old request and then try again.", nil);
    return;
  }
  _resolve = resolve;
  _reject = reject;
  MFMessageComposeViewController *messageComposeViewController = [[MFMessageComposeViewController alloc] init];
  messageComposeViewController.messageComposeDelegate = self;
  // messageComposeViewController.recipients = addresses;
  messageComposeViewController.body = message;
  UM_WEAKIFY(self);
  [UMUtilities performSynchronouslyOnMainThread:^{
    UM_ENSURE_STRONGIFY(self);
    [self.utils.currentViewController presentViewController:messageComposeViewController animated:YES completion:nil];
  }];
}
UM_EXPORT_METHOD_AS(sendSMSWithiMessageAsync,
                    sendSMS:(NSArray<NSString *> *)addresses
                    message:(NSString *)message
                    imessageAttachment:(NSDictionary *)imessageAttachment
                   resolver:(UMPromiseResolveBlock)resolve
                   rejecter:(UMPromiseRejectBlock)reject)
{
  if (![MFMessageComposeViewController canSendText]) {
    reject(@"E_SMS_UNAVAILABLE", @"SMS service not available", nil);
    return;
  }
  if (_resolve != nil || _reject != nil) {
    reject(@"E_SMS_SENDING_IN_PROGRESS", @"Different SMS sending in progress. Await the old request and then try again.", nil);
    return;
  }
  MSSession *session = [[MSSession alloc] init];
  // Create main imessage
  MSMessage *iMessage = [[MSMessage alloc] initWithSession: session];
  // Create imessage layout template
  MSMessageTemplateLayout *iMessageLayout = [[MSMessageTemplateLayout alloc] init];
  // Create imessage live layout template
  // Create url components 
  NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
  // Create query items array 
  NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc]init];
  // get inputs 
  NSDictionary<NSString*, NSString*> *urlQueryItems = imessageAttachment[@"urlQueryItems"];
  NSDictionary<NSString*, NSString*> *layoutParams = imessageAttachment[@"layoutParams"];
  NSString *summaryText = imessageAttachment[@"summaryText"];

  // Add all the url params to the query items array
  for (id key in urlQueryItems) {
      NSURLQueryItem *queryItem = [[NSURLQueryItem alloc]initWithName: key value: urlQueryItems[key]];
      [queryItems addObject: queryItem];
  }
  // assign the query items array to the url component
  urlComponents.queryItems = queryItems;
  for (id key in layoutParams) {
    if ([key isEqual: @"mediaFileUrl"]) {
//      NSURL *mediaFileUrl = [[NSURL alloc] initWithString: layoutParams[key]];
      UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:layoutParams[key]]]];
      [iMessageLayout setImage: image];
    } else if ([key isEqual: @"caption"]) {
      [iMessageLayout setCaption: layoutParams[key]];
    } else if ([key isEqual: @"imageTitle"]) {
      [iMessageLayout setImageTitle: layoutParams[key]];
    } else if ([key isEqual: @"imageSubtitle"]) {
      [iMessageLayout setImageSubtitle: layoutParams[key]];
    } else if ([key isEqual: @"subcaption"]) {
      [iMessageLayout setSubcaption: layoutParams[key]];
    } else if ([key isEqual: @"trailingCaption"]) {
      [iMessageLayout setTrailingCaption: layoutParams[key]];
    } else if ([key isEqual: @"trailingSubcaption"]) {
      [iMessageLayout setTrailingSubcaption: layoutParams[key]];
    }
  }
  // NSString *stringURL = [NSString stringWithFormat:@"%@%@",NSTemporaryDirectory(),@"temp.jpg"];
  // NSURL *urlImage = [[NSURL alloc]initFileURLWithPath:stringURL];
  // NSData *dataImage = UIImageJPEGRepresentation([self imageWithView:self.myViewBgImageConLogoDaSalvare], 0.0);
  //       [dataImage writeToURL:urlImage atomically:true];
  // Add layout and url params to main imessage
  iMessage.URL = urlComponents.URL;

  MSMessageTemplateLayout *iMessageLiveLayout = [[MSMessageLiveLayout alloc]initWithAlternateLayout: iMessageLayout];

  iMessage.layout = iMessageLiveLayout;  

  iMessage.summaryText = summaryText;  

  _resolve = resolve;
  _reject = reject;
  MFMessageComposeViewController *messageComposeViewController = [[MFMessageComposeViewController alloc] init];
  messageComposeViewController.messageComposeDelegate = self;
  if ([addresses[0] length] > 0) {
    messageComposeViewController.recipients = addresses;
  }
  messageComposeViewController.body = message;
  messageComposeViewController.message = iMessage;
  [self.utils.currentViewController presentViewController:messageComposeViewController animated:YES completion:nil];
}
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  NSDictionary *resolveData;
  NSString *rejectMessage;
  switch (result) {
    case MessageComposeResultCancelled:
      resolveData = @{@"result": @"cancelled"};
      break;
    case MessageComposeResultFailed:
      rejectMessage = @"SMS message sending failed";
      break;
    case MessageComposeResultSent:
      resolveData = @{@"result": @"sent"};
      break;
    default:
      rejectMessage = @"SMS message sending failed with unknown error";
      break;
  }
  UM_WEAKIFY(self);
  [controller dismissViewControllerAnimated:YES completion:^{
    UM_ENSURE_STRONGIFY(self);
    if (rejectMessage) {
      self->_reject(@"E_SMS_SENDING_FAILED", rejectMessage, nil);
    } else {
      self->_resolve(resolveData);
    }
    self->_reject = nil;
    self->_resolve = nil;
  }];
}
@end