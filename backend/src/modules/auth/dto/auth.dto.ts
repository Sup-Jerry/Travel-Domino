import { IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';

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

export class GuestCreateDto {
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

  @IsObject()
  deviceInfo!: DeviceInfoDto;
}

export class UpdateUsernameDto {
  @IsString()
  @IsNotEmpty()
  username!: string;
}

export class UpdateAvatarDto {
  @IsString()
  @IsNotEmpty()
  imageDataUrl!: string;

  @IsString()
  @IsOptional()
  mimeType?: string;
}
