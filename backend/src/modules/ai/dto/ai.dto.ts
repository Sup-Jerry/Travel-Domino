import { Type } from 'class-transformer';
import { IsArray, IsBoolean, IsIn, IsInt, IsNumber, IsOptional, IsString, Max, Min, ValidateNested } from 'class-validator';

export class AiChatMessageDto {
  @IsString()
  role!: string;

  @IsString()
  content!: string;
}

export class AiResponseFormatDto {
  @IsString()
  @IsIn(['json_object'])
  type!: 'json_object';
}

export class AiChatCompletionsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AiChatMessageDto)
  messages!: AiChatMessageDto[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(8192)
  max_tokens?: number;

  @IsOptional()
  @IsNumber()
  temperature?: number;

  @IsOptional()
  @IsBoolean()
  stream?: boolean;

  @IsOptional()
  @ValidateNested()
  @Type(() => AiResponseFormatDto)
  response_format?: AiResponseFormatDto;
}

