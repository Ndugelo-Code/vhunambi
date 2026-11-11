export type BeatLicenseTier =
  | 'basic_lease'
  | 'stems_trackout'
  | 'exclusive_stem'
  | 'unlimited_commercial';

export interface BeatStemPackageUrls {
  masterAudioUrl: string;
  drumsUrl?: string;
  bassUrl?: string;
  melodicUrl?: string;
  otherUrl?: string;
}

export interface MarketplaceBeatListing {
  id: string;
  producerId: string;
  producerHandle: string;
  producerName: string;
  title: string;
  genre: string;
  bpm: number;
  musicalKey: string;
  tags: string[];
  priceCoins: number;
  priceZar: number;
  previewAudioUrl: string;
  stemPackage: BeatStemPackageUrls;
  salesCount: number;
  auditionCount: number;
  licenseTiers: BeatLicenseTier[];
  isExclusiveSold?: boolean;
  exclusiveBuyerId?: string;
  mmoManifestUrl?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateBeatListingRequest {
  id?: string;
  producerId?: string;
  producerHandle?: string;
  producerName?: string;
  title: string;
  genre: string;
  bpm: number;
  musicalKey: string;
  tags?: string[];
  priceCoins?: number;
  priceZar?: number;
  previewAudioUrl: string;
  stemPackage?: Partial<BeatStemPackageUrls>;
  licenseTiers?: BeatLicenseTier[];
  mmoManifestUrl?: string;
}

export interface LicenseBeatRequest {
  buyerId: string;
  buyerHandle?: string;
  tier: BeatLicenseTier;
  paymentMethod?: 'coins' | 'credits' | 'zar';
  certificateId?: string;
  issuedAt?: string;
  masterFileSha256?: string;
  enforceWalletBalance?: boolean;
}

export interface BeatLicenseCertificate {
  certificateId: string;
  licenseHash: string;
  beatId: string;
  beatTitle: string;
  producerId: string;
  producerHandle: string;
  buyerId: string;
  buyerHandle: string;
  tier: BeatLicenseTier;
  amountPaidCoins: number;
  amountPaidZar: number;
  producerRoyaltyZar: number;
  producerRoyaltyCoins: number;
  issuedAt: string;
  commercialTerms: string;
  masterFileSha256?: string;
  stemUrls: BeatStemPackageUrls;
}

export interface MarketplaceFilterQuery {
  genre?: string;
  search?: string;
  minBpm?: number;
  maxBpm?: number;
  maxPrice?: number;
  cursor?: string;
  limit?: number;
}

