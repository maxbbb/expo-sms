import { Platform } from '@unimodules/core';
import ExpoSMS from './ExpoSMS';

type SMSResponse = {
  result: 'unknown' | 'sent' | 'cancelled';
};

type MSMessageLayout = {
  mediaFileUrl: string;
  caption?: string;
  imageTitle?: string;
  imageSubtitle?: string;
  subcaption?: string;
  trailingCaption?: string;
  trailingSubcaption?: string;
}

type URLQueryItems = any;

// example
// {
//   gameUrl: string;
//   gameId: string;
// }

type MSMessageInfo = {
  urlQueryItems: any;
  layoutParams: MSMessageLayout;
}

export async function sendSMSAsync(
  addresses: string | string[],
  message: string
): Promise<SMSResponse> {
  const finalAddresses = Array.isArray(addresses) ? addresses : [addresses];
  if (!ExpoSMS.sendSMSAsync) {
    throw new Error(`SMS.sendSMSAsync is not supported on ${Platform.OS}`);
  }
  return ExpoSMS.sendSMSAsync(finalAddresses, message);
}

export async function sendSMSWithiMessageAsync(
  addresses: string | string[],
  message: string,
  imessageInfo: MSMessageInfo
): Promise<SMSResponse> {
  const finalAddresses = Array.isArray(addresses) ? addresses : [addresses];
  if (!ExpoSMS.sendSMSAsync) {
    throw new Error(`SMS.sendSMSAsync is not supported on ${Platform.OS}`);
  }
  return ExpoSMS.sendSMSWithiMessageAsync(finalAddresses, message, imessageInfo);
}

export async function isAvailableAsync(): Promise<boolean> {
  return ExpoSMS.isAvailableAsync();
}
