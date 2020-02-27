//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "TSContactThread.h"
#import "ContactsManagerProtocol.h"
#import "NotificationsProtocol.h"
#import "OWSIdentityManager.h"
#import "SSKEnvironment.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const TSContactThreadLegacyPrefix = @"c";
NSUInteger const TSContactThreadSchemaVersion = 1;

@interface TSContactThread ()

@property (nonatomic, nullable, readonly) NSString *contactPhoneNumber;
@property (nonatomic, nullable, readonly) NSString *contactUUID;
@property (nonatomic, readonly) NSUInteger contactThreadSchemaVersion;

// From TSThread
@property (nonatomic) NSString *conversationColorName;

@end

@implementation TSContactThread

#pragma mark - Dependencies

+ (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

+ (AnyContactThreadFinder *)threadFinder
{
    return [AnyContactThreadFinder new];
}


#pragma mark -

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
           conversationColorName:(ConversationColorName)conversationColorName
                    creationDate:(nullable NSDate *)creationDate
                      isArchived:(BOOL)isArchived
            lastInteractionRowId:(int64_t)lastInteractionRowId
                    messageDraft:(nullable NSString *)messageDraft
                  mutedUntilDate:(nullable NSDate *)mutedUntilDate
           shouldThreadBeVisible:(BOOL)shouldThreadBeVisible
              contactPhoneNumber:(nullable NSString *)contactPhoneNumber
                     contactUUID:(nullable NSString *)contactUUID
              hasDismissedOffers:(BOOL)hasDismissedOffers
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId
             conversationColorName:conversationColorName
                      creationDate:creationDate
                        isArchived:isArchived
              lastInteractionRowId:lastInteractionRowId
                      messageDraft:messageDraft
                    mutedUntilDate:mutedUntilDate
             shouldThreadBeVisible:shouldThreadBeVisible];

    if (!self) {
        return self;
    }

    _contactPhoneNumber = contactPhoneNumber;
    _contactUUID = contactUUID;
    _hasDismissedOffers = hasDismissedOffers;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        // Migrate legacy threads to store phone number and UUID
        if (_contactThreadSchemaVersion < 1) {
            _contactPhoneNumber = [[self class] legacyContactPhoneNumberFromThreadId:self.uniqueId];
        }

        _contactThreadSchemaVersion = TSContactThreadSchemaVersion;
    }
    return self;
}

- (instancetype)initWithContactAddress:(SignalServiceAddress *)contactAddress
{
    OWSAssertDebug(contactAddress.isValid);

    if (self = [super init]) {
        _contactUUID = contactAddress.uuidString;
        _contactPhoneNumber = contactAddress.phoneNumber;
        _contactThreadSchemaVersion = TSContactThreadSchemaVersion;

        // Reset the conversation color to use our phone number, if available. The super initializer just uses the
        // uniqueId
        self.conversationColorName =
            [[self class] stableColorNameForNewConversationWithString:contactAddress.stringForDisplay];
    }

    return self;
}

+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                        transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(contactAddress.isValid);

    TSContactThread *thread = [self.threadFinder contactThreadForAddress:contactAddress transaction:transaction];

    if (!thread) {
        thread = [[TSContactThread alloc] initWithContactAddress:contactAddress];
        [thread anyInsertWithTransaction:transaction];
    }

    return thread;
}

+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
{
    OWSAssertDebug(contactAddress.isValid);

    __block TSContactThread *thread;
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction *transaction) {
        thread = [self getOrCreateThreadWithContactAddress:contactAddress transaction:transaction];
    }];

    return thread;
}

+ (nullable instancetype)getThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                         transaction:(SDSAnyReadTransaction *)transaction
{
    return [self.threadFinder contactThreadForAddress:contactAddress transaction:transaction];
}

- (SignalServiceAddress *)contactAddress
{
    return [[SignalServiceAddress alloc] initWithUuidString:self.contactUUID phoneNumber:self.contactPhoneNumber];
}

- (NSArray<SignalServiceAddress *> *)recipientAddresses
{
    return @[ self.contactAddress ];
}

- (BOOL)isGroupThread {
    return NO;
}

- (BOOL)isGroupV1Thread
{
    return NO;
}

- (BOOL)isGroupV2Thread
{
    return NO;
}

- (BOOL)isNoteToSelf
{
    if (!IsNoteToSelfEnabled()) {
        return NO;
    }

    return self.contactAddress.isLocalAddress;
}

- (NSString *)colorSeed
{
    NSString *_Nullable phoneNumber = self.contactAddress.phoneNumber;
    if (!phoneNumber) {
        phoneNumber = [[self class] legacyContactPhoneNumberFromThreadId:self.uniqueId];
    }

    return phoneNumber ?: self.uniqueId;
}

- (BOOL)hasSafetyNumbers
{
    return !![[OWSIdentityManager sharedManager] identityKeyForAddress:self.contactAddress];
}

+ (nullable SignalServiceAddress *)contactAddressFromThreadId:(NSString *)threadId
                                                  transaction:(SDSAnyReadTransaction *)transaction
{
    return [TSContactThread anyFetchContactThreadWithUniqueId:threadId transaction:transaction].contactAddress;
}

+ (nullable NSString *)legacyContactPhoneNumberFromThreadId:(NSString *)threadId
{
    if (![threadId hasPrefix:TSContactThreadLegacyPrefix]) {
        return nil;
    }

    return [threadId substringWithRange:NSMakeRange(1, threadId.length - 1)];
}

+ (NSString *)conversationColorNameForContactAddress:(SignalServiceAddress *)address
                                         transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(address);

    TSContactThread *_Nullable contactThread = [TSContactThread getThreadWithContactAddress:address
                                                                                transaction:transaction];
    if (contactThread) {
        return contactThread.conversationColorName;
    }
    return [self stableColorNameForNewConversationWithString:address.stringForDisplay];
}

@end

NS_ASSUME_NONNULL_END
