declare type SMSResponse = {
    result: 'unknown' | 'sent' | 'cancelled';
};

type MSMessageLayout = {
    mediaFileUrl: string;
    caption: string;
    imageTitle: string;
    imageSubtitle: string;
    subcaption: string;
    trailingCaption: string;
    trailingSubcaption: string;
  }
  
type URLQueryItems = any;
  
  // example
  // {
  //   gameUrl: string;
  //   gameId: string;
  // }
  
type MSMessageInfo = {
    urlQueryItems: URLQueryItems;
    layoutParams: MSMessageLayout;
}

  
export declare function sendSMSAsync(addresses: string | string[], message: string): Promise<SMSResponse>;
export declare function isAvailableAsync(): Promise<boolean>;
export declare function sendSMSWithiMessageAsync(addresses: string | string[], message: string, imessageInfo: MSMessageInfo): Promise<SMSResponse>;

export {};