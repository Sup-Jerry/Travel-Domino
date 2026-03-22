import { IsNotEmpty, IsObject, IsString } from 'class-validator';

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
