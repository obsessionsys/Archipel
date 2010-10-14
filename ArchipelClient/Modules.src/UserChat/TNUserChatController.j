/*
 * TNUserChat.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

/*! @defgroup  userchat Module User Chat
    @desc This module allows to chat with entities
*/


/*! @ingroup userchat
    The module main controller
*/
@implementation TNUserChatController : TNModule
{
    @outlet CPImageView     imageSpinnerWriting;
    @outlet CPScrollView    messagesScrollView;
    @outlet CPTextField     fieldJID;
    @outlet CPTextField     fieldMessage;
    @outlet CPTextField     fieldName;
    @outlet CPTextField     fieldPreferencesMaxChatMessage;
    @outlet CPTextField     fieldUserJID;

    CPArray                 _messages;
    CPTimer                 _composingMessageTimer;
    TNMessageBoard          _messageBoard;
}


#pragma mark -
#pragma mark Initialization

/*! called at cib awakening
*/
- (void)awakeFromCib
{
    var bundle      = [CPBundle bundleForClass:[self class]],
        mainBundle  = [CPBundle mainBundle],
        defaults    = [TNUserDefaults standardUserDefaults],
        frame       = [[messagesScrollView contentView] bounds];

    // register defaults defaults
    [defaults registerDefaults:[CPDictionary dictionaryWithObjectsAndKeys:
            [bundle objectForInfoDictionaryKey:@"TNUserChatMaxMessageStore"], @"TNUserChatMaxMessageStore"
    ]];

    [fieldJID setSelectable:YES];

    _messages = [CPArray array];

    [messagesScrollView setBorderedWithHexColor:@"#C0C7D2"];
    [messagesScrollView setAutoresizingMask:CPViewWidthSizable];
    [messagesScrollView setAutohidesScrollers:YES];

    frame.size.height = 0;
    _messageBoard = [[TNMessageBoard alloc] initWithFrame:frame];
    [_messageBoard setAutoresizingMask:CPViewWidthSizable];

    [messagesScrollView setDocumentView:_messageBoard];


    [imageSpinnerWriting setImage:[[CPImage alloc] initWithContentsOfFile:[mainBundle pathForResource:@"spinner.gif"]]];
    [imageSpinnerWriting setHidden:YES];

    [fieldMessage addObserver:self forKeyPath:@"stringValue" options:CPKeyValueObservingOptionNew context:nil];
}


#pragma mark -
#pragma mark TNModule overrides

/*! called when module is loaded
*/
- (void)willLoad
{
    [super willLoad];

    var center = [CPNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_didReceiveMessage:) name:TNStropheContactMessageReceivedNotification object:_entity];
    [center addObserver:self selector:@selector(_didReceiveMessageComposing:) name:TNStropheContactMessageComposing object:_entity];
    [center addObserver:self selector:@selector(_didReceiveMessagePause:) name:TNStropheContactMessagePaused object:_entity];
    [center addObserver:self selector:@selector(_didUpdateNickName:) name:TNStropheContactNicknameUpdatedNotification object:_entity];

    var frame = [[messagesScrollView documentView] bounds];

    [_messageBoard removeAllMessages:nil];

    _messages = [CPArray array];

    [self restore];

    var frame = [[messagesScrollView documentView] frame],
        newScrollOrigin = CPMakePoint(0.0, frame.size.height);

    [_messageBoard scrollPoint:newScrollOrigin];

    [center postNotificationName:TNArchipelModulesReadyNotification object:self];
}

/*! called when module is unloaded
*/- (void)willUnload
{
    [super willUnload];

    [_messages removeAllObjects];
    [_messageBoard removeAllMessages:nil];
}

/*! called when module becomes visible
*/
- (void)willShow
{
    [super willShow];

    var messageQueue = [_entity messagesQueue],
        stanza;

    while (stanza = [_entity popMessagesQueue])
    {
        if ([stanza containsChildrenWithName:@"body"])
        {
            var from    = ([stanza valueForAttribute:@"from"] == @"me") ? @"me" : [_entity nickname],
                message = [[stanza firstChildWithName:@"body"] text],
                color   = ([stanza valueForAttribute:@"from"] == @"me") ? [CPColor ] : [_entity nickname];

            [self appendMessageToBoard:message from:from];
        }
    }

    [_entity freeMessagesQueue];

    [fieldName setStringValue:[_entity nickname]];
    [fieldJID setStringValue:[_entity JID]];
}

/*! called when user saves preferences
*/
- (void)savePreferences
{
    var defaults = [TNUserDefaults standardUserDefaults];

    [defaults setInteger:[fieldPreferencesMaxChatMessage stringValue] forKey:@"TNUserChatMaxMessageStore"];
}

/*! called when user gets preferences
*/
- (void)loadPreferences
{
    var defaults = [TNUserDefaults standardUserDefaults];

    [fieldPreferencesMaxChatMessage setStringValue:[defaults integerForKey:@"TNUserChatMaxMessageStore"]];
}

/*! called when MainMenu is ready
*/
- (void)menuReady
{
    var sendMenu    = [_menu addItemWithTitle:@"Send message" action:@selector(sendMessage:) keyEquivalent:@""],
        clearMenu   = [_menu addItemWithTitle:@"Clear history" action:@selector(clearHistory:) keyEquivalent:@""];

    [sendMenu setTarget:self];
    [clearMenu setTarget:self];
}


#pragma mark -
#pragma mark Notification handlers

/*! triggered when entity's nickname changed
    @param aNotification the notification
*/
- (void)_didUpdateNickName:(CPNotification)aNotification
{
    if ([aNotification object] == _entity)
    {
       [fieldName setStringValue:[_entity nickname]]
    }
}

/*! performed when TNStropheContactMessageReceivedNotification is received from current entity.
    @param aNotification the notification containing the contact that send the notification
*/
- (void)_didReceiveMessage:(CPNotification)aNotification
{
    if ([[aNotification object] JID] == [_entity JID])
    {
        var stanza =  [_entity popMessagesQueue];

        if ([stanza containsChildrenWithName:@"body"])
        {
            var messageBody = [[stanza firstChildWithName:@"body"] text];

            [imageSpinnerWriting setHidden:YES];
            [self appendMessageToBoard:messageBody from:[_entity nickname]];

            CPLog.info(@"message received : " + messageBody);
        }
    }
    else
    {
        _audioTagReceive.play();
    }
}

/*! performed when TNStropheContactMessageComposing is received from current entity.
    @param aNotification the notification containing the contact that send the notification
*/
- (void)_didReceiveMessageComposing:(CPNotification)aNotification
{
    [imageSpinnerWriting setHidden:NO];
}

/*! performed when TNStropheContactMessagePaused is received from current entity.
    @param aNotification the notification containing the contact that send the notification
*/
- (void)_didReceiveMessagePause:(CPNotification)aNotification
{
    [imageSpinnerWriting setHidden:YES];
}

/*! observe if user is typing. If yes then send the "compose" XMPP status.
    @param aKeyPath the key path observed
    @param anObject the object observed
    @param aChange changes
    @param aContext a context
*/
- (void)observeValueForKeyPath:(CPString)aKeyPath ofObject:(id)anObject change:(CPDictionary)aChange context:(id)aContext
{
    if ([anObject stringValue] == @"")
    {
        [_entity sendComposePaused];
    }
    else
    {
        if (_composingMessageTimer)
            [_composingMessageTimer invalidate];

        _composingMessageTimer = [CPTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(sendComposingPaused:) userInfo:nil repeats:NO];
        [_entity sendComposing];
    }

}


#pragma mark -
#pragma mark Utilities

/*! save the chat
*/
- (void)save
{
    var defaults        = [TNUserDefaults standardUserDefaults],
        max             = [_messages count],
        saveMax         = [defaults integerForKey:@"TNUserChatMaxMessageStore"],
        location        = ((max - saveMax) > 0) ? (max - saveMax) : 0,
        lenght          = (saveMax <= max) ? saveMax : max,
        messagesToSave  = [_messages subarrayWithRange:CPMakeRange(location, lenght)];

    CPLog.debug(@"count=" + [_messages count] + " location=" + location + " lenght:" + lenght);

    [defaults setObject:messagesToSave forKey:"communicationWith" + [_entity JID]];
}

/*! restore the chat
*/
- (void)restore
{
    var defaults = [TNUserDefaults standardUserDefaults],
        lastConversation = [defaults objectForKey:"communicationWith" + [_entity JID]];

    if (lastConversation)
        _messages = lastConversation;

    for (var j = 0; j < [lastConversation count]; j++)
    {
        var author  = [[lastConversation objectAtIndex:j] objectForKey:@"name"],
            message = [[lastConversation objectAtIndex:j] objectForKey:@"message"],
            color   = [[lastConversation objectAtIndex:j] objectForKey:@"color"],
            date   = [[lastConversation objectAtIndex:j] objectForKey:@"date"];

        [_messageBoard addMessage:message from:author date:date color:color];
    }
}

/*! this message is sent when user is not typing for some time
    @param aTimer the timer that call the selector
*/
- (void)sendComposingPaused:(CPTimer)aTimer
{
    [_entity sendComposePaused];
}

/*! append a new message to the message board
    @param aMessage the message body
    @param aSender the nickname of the sender
*/
- (void)appendMessageToBoard:(CPString)aMessage from:(CPString)aSender
{
    var color           = (aSender == @"me") ? [CPColor colorWithHexString:@"d9dfe8"] : [CPColor colorWithHexString:@"ffffff"],
        date            = [CPDate date],
        newMessageDict  = [CPDictionary dictionaryWithObjectsAndKeys:aSender, @"name", aMessage, @"message", color, @"color", date, @"date"],
        frame           = [[messagesScrollView documentView] frame];

    [_messages addObject:newMessageDict];
    [_messageBoard addMessage:aMessage from:aSender date:date color:color];

    // scroll to bottom;
    var newScrollOrigin = CPMakePoint(0.0, frame.size.height);
    [_messageBoard scrollPoint:newScrollOrigin];

    [self save];
}


#pragma mark -
#pragma mark Actions

/*! send a message to the contact containing the content of the outlet message CPTextField
    @param aSender the sender of the action
*/
- (IBAction)sendMessage:(id)aSender
{
     if (_composingMessageTimer)
            [_composingMessageTimer invalidate];

    [_entity sendMessage:[fieldMessage stringValue]];
    [self appendMessageToBoard:[fieldMessage stringValue] from:@"me"];
    [fieldMessage setStringValue:@""];
}

/*! Clear all localstorage  of the old messages
    @param aSender the sender of the action
*/
- (IBAction)clearHistory:(id)aSender
{
    var defaults = [TNUserDefaults standardUserDefaults];

    [defaults removeObjectForKey:"communicationWith" + [_entity JID]];

    [_messages removeAllObjects];
    [_messageBoard removeAllMessages:nil];
}

@end