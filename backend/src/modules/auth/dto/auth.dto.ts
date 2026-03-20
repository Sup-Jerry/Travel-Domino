import { IsArray, IsBoolean, IsNotEmpty, IsObject, IsOptional, IsString, Length } from 'class-validator';

export class DeviceInfoDto {
  @IsString()
  @IsNotEmpty()
  deviceId!: string;

  @IsString()
  @IsNotEmpty()
  deviceName!: string;

  @IsString()
  @IsNotEmpty()
  platform!: string;
}

export class SendCodeDto {
  @IsString()
  @Length(6, 20)
  phoneNumber!: string;

  @IsString()
  @IsNotEmpty()
  countryCode!: string;

  @IsString()
  @IsNotEmpty()
  bizType!: string;
}

export class PhoneLoginDto {
  @IsString()
  @Length(6, 20)
  phoneNumber!: string;

  @IsString()
  @IsNotEmpty()
  countryCode!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsBoolean()
  agreementAccepted!: boolean;

  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class SocialCredentialDto {
  @IsString()
  @IsOptional()
  authCode?: string;

  @IsString()
  @IsOptional()
  idToken?: string;

  @IsString()
  @IsOptional()
  accessToken?: string;

  @IsString()
  @IsOptional()
  openId?: string;

  @IsString()
  @IsOptional()
  unionId?: string;
}

export class SocialLoginDto {
  @IsString()
  @IsNotEmpty()
  providerType!: string;

  @IsObject()
  credential!: SocialCredentialDto;

  @IsBoolean()
  agreementAccepted!: boolean;

  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class SocialCreateAccountDto {
  @IsString()
  @IsNotEmpty()
  pendingToken!: string;

  @IsString()
  @IsNotEmpty()
  nickname!: string;

  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @IsBoolean()
  agreementAccepted!: boolean;

  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class SocialBindExistingPhoneDto {
  @IsString()
  @IsNotEmpty()
  pendingToken!: string;

  @IsString()
  @Length(6, 20)
  phoneNumber!: string;

  @IsString()
  @IsNotEmpty()
  countryCode!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class GuestCreateDto {
  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class GuestUpgradeDto {
  @IsString()
  @IsNotEmpty()
  guestUserId!: string;

  @IsString()
  @IsNotEmpty()
  targetUserId!: string;
}

export class RefreshSessionDto {
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}

export class BindSocialDto {
  @IsString()
  @IsNotEmpty()
  providerType!: string;

  @IsObject()
  credential!: SocialCredentialDto;
}

export class BindPhoneDto {
  @IsString()
  @Length(6, 20)
  phoneNumber!: string;

  @IsString()
  @IsNotEmpty()
  countryCode!: string;

  @IsString()
  @Length(4, 8)
  code!: string;
}

export class UnbindDto {
  @IsString()
  @IsNotEmpty()
  providerType!: string;
}

export class LogoutDto {
  @IsString()
  @IsNotEmpty()
  sessionId!: string;
}

export class CancelRequestDto {
  @IsString()
  @IsNotEmpty()
  reauthToken!: string;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class NeedBindOrCreateDto {
  @IsString()
  action!: string;

  @IsString()
  pendingToken!: string;

  @IsObject()
  providerProfile!: Record<string, string>;

  @IsArray()
  suggestedActions!: string[];
}
