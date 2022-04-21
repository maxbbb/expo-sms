// Copyright © 2018 650 Industries. All rights reserved.
#import <MessageUI/MessageUI.h>
#import <Messages/Messages.h>
#import <EXSMS/EXSMSModule.h>
#import <ExpoModulesCore/EXUtilities.h>
#if SD_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
@interface EXSMSModule () <MFMessageComposeViewControllerDelegate>

@property (nonatomic, weak) id<EXUtilitiesInterface> utils;
@property (nonatomic, strong) EXPromiseResolveBlock resolve;
@property (nonatomic, strong) EXPromiseRejectBlock reject;


@end

@implementation EXSMSModule

EX_EXPORT_MODULE(ExpoSMS);

- (dispatch_queue_t)methodQueue
{
  // Everything in this module uses `MFMessageComposeViewController` which is a subclass of UIViewController,
  // so everything should be called from main thread.
  return dispatch_get_main_queue();
}

- (void)setModuleRegistry:(EXModuleRegistry *)moduleRegistry
{
  _utils = [moduleRegistry getModuleImplementingProtocol:@protocol(EXUtilitiesInterface)];
}


EX_EXPORT_METHOD_AS(isAvailableAsync,
                    isAvailable:(EXPromiseResolveBlock)resolve
                    rejecter:(EXPromiseRejectBlock)reject)
{
  resolve(@([MFMessageComposeViewController canSendText]));
}

EX_EXPORT_METHOD_AS(sendSMSAsync,
                    sendSMS:(NSArray<NSString *> *)addresses
                    message:(NSString *)message
                   resolver:(EXPromiseResolveBlock)resolve
                   rejecter:(EXPromiseRejectBlock)reject)
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
  
  [self.utils.currentViewController presentViewController:messageComposeViewController animated:YES completion:nil];

}

EX_EXPORT_METHOD_AS(sendSMSWithiMessageAsync,
                    sendSMS:(NSArray<NSString *> *)addresses
                    message:(NSString *)message
                    imessageAttachment:(NSDictionary *)imessageAttachment
                   resolver:(EXPromiseResolveBlock)resolve
                   rejecter:(EXPromiseRejectBlock)reject)
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

  EX_WEAKIFY(self);
  [controller dismissViewControllerAnimated:YES completion:^{
    EX_ENSURE_STRONGIFY(self);
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