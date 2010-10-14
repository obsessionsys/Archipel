/*
 * TNViewHypervisorControl.j
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

@import "TNExtendedContactObject.j";

TNArchipelPushNotificationDefinition            = @"archipel:push:virtualmachine:definition";
TNArchipelPushNotificationControl               = @"archipel:push:virtualmachine:control";

TNArchipelControlNotification                   = @"TNArchipelControlNotification";
TNArchipelControlPlay                           = @"TNArchipelControlPlay";
TNArchipelControlSuspend                        = @"TNArchipelControlSuspend";
TNArchipelControlResume                         = @"TNArchipelControlResume";
TNArchipelControlStop                           = @"TNArchipelControlStop";
TNArchipelControlDestroy                        = @"TNArchipelControlDestroy";
TNArchipelControlReboot                         = @"TNArchipelControlReboot";

TNArchipelTypeVirtualMachineControl             = @"archipel:vm:control";
TNArchipelTypeVirtualMachineControlInfo         = @"info";
TNArchipelTypeVirtualMachineControlCreate       = @"create";
TNArchipelTypeVirtualMachineControlShutdown     = @"shutdown";
TNArchipelTypeVirtualMachineControlDestroy      = @"destroy";
TNArchipelTypeVirtualMachineControlReboot       = @"reboot";
TNArchipelTypeVirtualMachineControlSuspend      = @"suspend";
TNArchipelTypeVirtualMachineControlResume       = @"resume";
TNArchipelTypeVirtualMachineControlMigrate      = @"migrate";
TNArchipelTypeVirtualMachineControlAutostart    = @"autostart";
TNArchipelTypeVirtualMachineControlMemory       = @"memory";
TNArchipelTypeVirtualMachineControlVCPUs        = @"setvcpus";

VIR_DOMAIN_NOSTATE  = 0;
VIR_DOMAIN_RUNNING  = 1;
VIR_DOMAIN_BLOCKED  = 2;
VIR_DOMAIN_PAUSED   = 3;
VIR_DOMAIN_SHUTDOWN = 4;
VIR_DOMAIN_SHUTOFF  = 5;
VIR_DOMAIN_CRASHED  = 6;

TNArchipelTransportBarPlay      = 0;
TNArchipelTransportBarPause     = 1;
TNArchipelTransportBarStop      = 2;
TNArchipelTransportBarDestroy   = 3
TNArchipelTransportBarReboot    = 4;


/*! @defgroup  virtualmachinecontrols Module VirtualMachine Controls
    @desc Allow to controls virtual machine
*/

/*! @ingroup virtualmachinecontrols
    main class of the module
*/
@implementation TNVirtualMachineControlsController : TNModule
{
    @outlet CPImageView             imageState;
    @outlet CPSegmentedControl      buttonBarTransport;
    @outlet CPTextField             fieldInfoConsumedCPU;
    @outlet CPTextField             fieldInfoCPUs;
    @outlet CPTextField             fieldInfoMem;
    @outlet CPTextField             fieldInfoState;
    @outlet CPTextField             fieldJID;
    @outlet CPTextField             fieldName;
    @outlet CPView                  maskingView;
    @outlet CPScrollView            scrollViewTableHypervisors;
    @outlet CPSearchField           filterHypervisors;
    @outlet CPButtonBar             buttonBarMigration;
    @outlet CPView                  viewTableHypervisorsContainer;
    @outlet CPSlider                sliderMemory;
    @outlet TNStepper               stepperCPU;
    @outlet CPTextField             fieldPreferencesMaxCPUs;

    CPTableView             _tableHypervisors;
    TNTableViewDataSource   _datasourceHypervisors;
    CPButton                _migrateButton;
    CPString                _currentHypervisorJID;

    CPNumber    _VMLibvirtStatus;
    CPImage     _imagePlay;
    CPImage     _imageStop;
    CPImage     _imageDestroy;
    CPImage     _imagePause;
    CPImage     _imageReboot;
    CPImage     _imageResume;
    CPImage     _imagePlayDisabled;
    CPImage     _imageStopDisabled;
    CPImage     _imageDestroyDisabled;
    CPImage     _imagePauseDisabled;
    CPImage     _imageRebootDisabled;
    CPImage     _imagePlaySelected;
    CPImage     _imageStopSelected;
    @outlet     TNSwitch    switchAutoStart;
}

#pragma mark -
#pragma mark Initialization

/*! called at cib awaking
*/
- (void)awakeFromCib
{
    var bundle      = [CPBundle bundleForClass:[self class]],
        defaults    = [TNUserDefaults standardUserDefaults];

    // register defaults defaults
    [defaults registerDefaults:[CPDictionary dictionaryWithObjectsAndKeys:
           [bundle objectForInfoDictionaryKey:@"TNArchipelControlsMaxVCPUs"], @"TNArchipelControlsMaxVCPUs"
    ]];

    [fieldJID setSelectable:YES];
    [sliderMemory setSendsActionOnEndEditing:YES];
    [sliderMemory setContinuous:NO];
    [stepperCPU setTarget:self];
    [stepperCPU setAction:@selector(setVCPUs:)];
    [stepperCPU setMinValue:1];
    [stepperCPU setMaxValue:[defaults integerForKey:@"TNArchipelControlsMaxVCPUs"]];



    _imagePlay              = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-play.png"] size:CGSizeMake(20, 20)];
    _imageStop              = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-stop.png"] size:CGSizeMake(20, 20)];
    _imageDestroy           = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-unplug.png"] size:CGSizeMake(20, 20)];
    _imagePause             = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-pause.png"] size:CGSizeMake(20, 20)];
    _imageReboot            = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-restart.png"] size:CGSizeMake(16, 16)];
    _imageResume            = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-resume.png"] size:CGSizeMake(16, 16)];

    _imagePlayDisabled      = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-play-disabled.png"] size:CGSizeMake(20, 20)];
    _imageStopDisabled      = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-stop-disabled.png"] size:CGSizeMake(20, 20)];
    _imageDestroyDisabled   = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-unplug-disabled.png"] size:CGSizeMake(20, 20)];
    _imagePauseDisabled     = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-pause-disabled.png"] size:CGSizeMake(20, 20)];
    _imageRebootDisabled    = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-restart-disabled.png"] size:CGSizeMake(16, 16)];

    _imagePlaySelected      = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-play-selected.png"] size:CGSizeMake(20, 20)];
    _imageStopSelected      = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-stop-selected.png"] size:CGSizeMake(20, 20)];



    [maskingView setBackgroundColor:[CPColor whiteColor]];
    [maskingView setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [maskingView setAlphaValue:0.9];

    [fieldJID setSelectable:YES];

    [buttonBarTransport setSegmentCount:5];
    [buttonBarTransport setLabel:@"Play" forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setLabel:@"Pause" forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setLabel:@"Stop" forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setLabel:@"Destroy" forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setLabel:@"Reboot" forSegment:TNArchipelTransportBarReboot];

    [buttonBarTransport setWidth:100 forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setWidth:100 forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setWidth:100 forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setWidth:100 forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setWidth:100 forSegment:TNArchipelTransportBarReboot];

    [buttonBarTransport setImage:_imagePlay forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setImage:_imagePause forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setImage:_imageStop forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setImage:_imageDestroy forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setImage:_imageReboot forSegment:TNArchipelTransportBarReboot];

    [buttonBarTransport setTarget:self];
    [buttonBarTransport setAction:@selector(segmentedControlClicked:)];


    // table migration
    [viewTableHypervisorsContainer setBorderedWithHexColor:@"#C0C7D2"];

    _datasourceHypervisors   = [[TNTableViewDataSource alloc] init];
    _tableHypervisors        = [[CPTableView alloc] initWithFrame:[scrollViewTableHypervisors bounds]];

    [scrollViewTableHypervisors setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [scrollViewTableHypervisors setAutohidesScrollers:YES];
    [scrollViewTableHypervisors setDocumentView:_tableHypervisors];

    [_tableHypervisors setUsesAlternatingRowBackgroundColors:YES];
    [_tableHypervisors setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [_tableHypervisors setAllowsColumnReordering:YES];
    [_tableHypervisors setAllowsColumnResizing:YES];
    [_tableHypervisors setTarget:self];
    [_tableHypervisors setDoubleAction:@selector(migrate:)];
    [_tableHypervisors setAllowsEmptySelection:YES];
    [_tableHypervisors setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];

    var columnName      = [[CPTableColumn alloc] initWithIdentifier:@"nickname"],
        columnStatus    = [[CPTableColumn alloc] initWithIdentifier:@"isSelected"],
        imgView         = [[CPImageView alloc] initWithFrame:CGRectMake(0,0,16,16)];

    [columnName setWidth:200]
    [[columnName headerView] setStringValue:@"Name"];
    [columnName setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"nickname" ascending:YES]];

    [imgView setImageScaling:CPScaleNone];
    [columnStatus setDataView:imgView];
    [columnStatus setResizingMask:CPTableColumnAutoresizingMask ];
    [columnStatus setWidth:16];
    [[columnStatus headerView] setStringValue:@""];

    [filterHypervisors setTarget:_datasourceHypervisors];
    [filterHypervisors setAction:@selector(filterObjects:)];
    [_datasourceHypervisors setSearchableKeyPaths:[@"nickname"]];

    [_tableHypervisors addTableColumn:columnStatus];
    [_tableHypervisors addTableColumn:columnName];
    [_datasourceHypervisors setTable:_tableHypervisors];
    [_tableHypervisors setDataSource:_datasourceHypervisors];

    // button bar migration

    _migrateButton  = [CPButtonBar plusButton];
    [_migrateButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-migrate.png"] size:CPSizeMake(16, 16)]];
    [_migrateButton setTarget:self];
    [_migrateButton setAction:@selector(migrate:)];

    [_migrateButton setEnabled:NO];
    [buttonBarMigration setButtons:[_migrateButton]];

    //TNSwitch
    // switchAutoStart = [TNSwitch switchWithFrame:CGRectMake(653, 130, 77, 24)];
    // [[self view] addSubview:switchAutoStart];

    [switchAutoStart setTarget:self];
    [switchAutoStart setAction:@selector(setAutostart:)];
}


#pragma mark -
#pragma mark TNModule overrides

/*! called when module is loaded
*/
- (void)willLoad
{
    [super willLoad];

    var center = [CPNotificationCenter defaultCenter];

    [center addObserver:self selector:@selector(_didUpdateNickName:) name:TNStropheContactNicknameUpdatedNotification object:_entity];
    [center addObserver:self selector:@selector(_didReceiveControlNotification:) name:TNArchipelControlNotification object:nil];
    [center postNotificationName:TNArchipelModulesReadyNotification object:self];

    [self registerSelector:@selector(_didReceivePush:) forPushNotificationType:TNArchipelPushNotificationControl];
    [self registerSelector:@selector(_didReceivePush:) forPushNotificationType:TNArchipelPushNotificationDefinition];

    [self disableAllButtons];

    [fieldName setStringValue:[_entity nickname]];
    [fieldJID setStringValue:[_entity JID]];
    [imageState setImage:[_entity statusIcon]];
}

/*! called when module is unloaded
*/
- (void)willUnload
{
    [super willUnload];

    [fieldInfoMem setStringValue:@"..."];
    [fieldInfoCPUs setStringValue:@"..."];
    [fieldInfoConsumedCPU setStringValue:@"..."];
    [fieldInfoState setStringValue:@"..."];
    [imageState setImage:nil];

    [self disableAllButtons];
    [buttonBarTransport setLabel:@"Pause" forSegment:TNArchipelTransportBarPause];
}

/*! called when module becomes visible
*/
- (void)willShow
{
    [super willShow];

    [maskingView setFrame:[[self view] bounds]];

    [self checkIfRunning];

    [_tableHypervisors setDelegate:nil];
    [_tableHypervisors setDelegate:self];

    [viewTableHypervisorsContainer setHidden:YES];
    [filterHypervisors setHidden:YES];
    [switchAutoStart setEnabled:NO];
    [switchAutoStart setOn:NO animated:YES sendAction:NO];
    [sliderMemory setEnabled:NO];
    [stepperCPU setEnabled:NO];

    [_tableHypervisors deselectAll];
    [self populateHypervisorsTable];
}

/*! called when module becomes unvisible
*/
- (void)willHide
{
    [super willHide];
}

/*! called when MainMenu is ready
*/
- (void)menuReady
{
    [[_menu addItemWithTitle:@"Start" action:@selector(play:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:@"Shutdown" action:@selector(shutdown:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:@"Pause / Resume" action:@selector(pause:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:@"Reboot" action:@selector(reboot:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:@"Destroy" action:@selector(destroy:) keyEquivalent:@""] setTarget:self];
}

/*! called when user saves preferences
*/
- (void)savePreferences
{
    var defaults = [TNUserDefaults standardUserDefaults];

    [defaults setInteger:[fieldPreferencesMaxCPUs stringValue] forKey:@"TNArchipelControlsMaxVCPUs"];
}

/*! called when user gets preferences
*/
- (void)loadPreferences
{
    var defaults = [TNUserDefaults standardUserDefaults];

    [fieldPreferencesMaxCPUs setStringValue:[defaults integerForKey:@"TNArchipelControlsMaxVCPUs"]];
}


#pragma mark -
#pragma mark Notification handlers

/*! called when entity's nickname changes
    @param aNotification the notification
*/
- (void)_didUpdateNickName:(CPNotification)aNotification
{
    [fieldName setStringValue:[_entity nickname]]
}

/*! called if entity changes it presence and call checkIfRunning
    @param aNotification the notification
*/
- (void)_didUpdatePresence:(CPNotification)aNotification
{
    // [imageState setImage:[_entity statusIcon]];
    //
    // [self checkIfRunning];
}

/*! called when an Archipel push is received
    @param somePushInfo CPDictionary containing the push information
*/
- (BOOL)_didReceivePush:(CPDictionary)somePushInfo
{
    var sender  = [somePushInfo objectForKey:@"owner"],
        type    = [somePushInfo objectForKey:@"type"],
        change  = [somePushInfo objectForKey:@"change"],
        date    = [somePushInfo objectForKey:@"date"];

    CPLog.info(@"PUSH NOTIFICATION: from: " + sender + ", type: " + type + ", change: " + change);

    [self checkIfRunning];

    return YES;
}

/*! called when recieve a control notification
*/
- (void)_didReceiveControlNotification:(CPNotification)aNotification
{
    var command = [aNotification userInfo];

    switch (command)
    {
        case TNArchipelControlPlay:
            [self play:nil];
            break;
        case (TNArchipelControlSuspend || TNArchipelControlResume):
            [self pause:nil];
            break;
        case TNArchipelControlReboot:
            [self reboot:nil];
            break;
        case TNArchipelControlStop:
            [self stop:nil];
            break;
        case TNArchipelControlDestroy:
            [self destroy:nil];
            break;
    }
}


#pragma mark -
#pragma mark Utilities

/*! check if virtual machine is running and adapt the GUI
*/
- (void)checkIfRunning
{
    var XMPPShow = [_entity XMPPShow];

    [self getVirtualMachineInfo];

    if ((XMPPShow == TNStropheContactStatusDND))
    {
        [maskingView setFrame:[[self view] bounds]];
        [[self view] addSubview:maskingView];
    }
    else
        [maskingView removeFromSuperview];
}

/*! populate the migration table with all hypervisors in roster
*/
- (void)populateHypervisorsTable
{
    [_datasourceHypervisors removeAllObjects];
    var rosterItems = [_roster contacts];

    for (var i = 0; i < [rosterItems count]; i++)
    {
        var item = [rosterItems objectAtIndex:i];

        if ([[[item vCard] firstChildWithName:@"TYPE"] text] == @"hypervisor")
        {
            var o = [[TNExtendedContact alloc] initWithNickName:[item nickname] fullJID:[item fullJID]];

            [_datasourceHypervisors addObject:o];
        }
    }
    [_tableHypervisors reloadData];

}

/*! layout segmented controls button according to virtual machine state
    @pathForResource libvirtState the state of the virtual machine
*/
- (void)layoutButtons:(id)libvirtState
{
    switch ([libvirtState intValue])
    {
        case VIR_DOMAIN_NOSTATE:
            humanState = @"No status";
            break;
        case VIR_DOMAIN_RUNNING:
            [self enableButtonsForRunning];
            humanState = @"Running";
            break;
        case VIR_DOMAIN_BLOCKED:
            humanState = @"Blocked";
            break;
        case VIR_DOMAIN_PAUSED:
            [self enableButtonsForPaused]
            humanState = @"Paused";
            break;
        case VIR_DOMAIN_SHUTDOWN:
            [self enableButtonsForShutdowned]
            humanState = @"Shutdown";
            break;
        case VIR_DOMAIN_SHUTOFF:
            [self enableButtonsForShutdowned]
            humanState = @"Shutdown";
            break;
        case VIR_DOMAIN_CRASHED:
            humanState = @"Crashed";
            break;
  }
  [fieldInfoState setStringValue:humanState];
  [imageState setImage:[_entity statusIcon]];
}

/*! enable buttons necessary when virtual machine is running
*/
- (void)enableButtonsForRunning
{
    [buttonBarTransport setSelectedSegment:TNArchipelTransportBarPlay];

    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarReboot];
    [buttonBarTransport setLabel:@"Pause" forSegment:TNArchipelTransportBarPause];

    [buttonBarTransport setImage:_imagePlaySelected forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setImage:_imageStop forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setImage:_imageDestroy forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setImage:_imagePause forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setImage:_imageReboot forSegment:TNArchipelTransportBarReboot];

    var imagePause  = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-pause.png"] size:CGSizeMake(20, 20)];
    [buttonBarTransport setImage:_imagePause forSegment:TNArchipelTransportBarPause];
}

/*! enable buttons necessary when virtual machine is paused
*/
- (void)enableButtonsForPaused
{
    [buttonBarTransport setSelectedSegment:TNArchipelTransportBarPause];

    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarReboot];
    [buttonBarTransport setLabel:@"Resume" forSegment:TNArchipelTransportBarPause];

    [buttonBarTransport setImage:_imagePlayDisabled forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setImage:_imageStop forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setImage:_imageDestroy forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setImage:_imageResume forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setImage:_imageReboot forSegment:TNArchipelTransportBarReboot];
}

/*! enable buttons necessary when virtual machine is shutdowned
*/
- (void)enableButtonsForShutdowned
{
    [buttonBarTransport setSelectedSegment:TNArchipelTransportBarStop];

    [buttonBarTransport setEnabled:YES forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarReboot];
    [buttonBarTransport setLabel:@"Pause" forSegment:TNArchipelTransportBarPause];

    [buttonBarTransport setImage:_imagePlay forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setImage:_imageStopSelected forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setImage:_imageDestroyDisabled forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setImage:_imagePauseDisabled forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setImage:_imageRebootDisabled forSegment:TNArchipelTransportBarReboot];
}

/*! disable all buttons
*/
- (void)disableAllButtons
{
    [buttonBarTransport setSelected:NO forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setSelected:NO forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setSelected:NO forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setSelected:NO forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setSelected:NO forSegment:TNArchipelTransportBarReboot];

    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setEnabled:NO forSegment:TNArchipelTransportBarReboot];

    [buttonBarTransport setImage:_imagePlayDisabled forSegment:TNArchipelTransportBarPlay];
    [buttonBarTransport setImage:_imageStopDisabled forSegment:TNArchipelTransportBarStop];
    [buttonBarTransport setImage:_imageDestroyDisabled forSegment:TNArchipelTransportBarDestroy];
    [buttonBarTransport setImage:_imagePauseDisabled forSegment:TNArchipelTransportBarPause];
    [buttonBarTransport setImage:_imageRebootDisabled forSegment:TNArchipelTransportBarReboot];
}


#pragma mark -
#pragma mark Action

/*! triggered when segmented control is clicked
    @param aSender the sender of the action
*/
- (IBAction)segmentedControlClicked:(id)aSender
{
    var segment = [aSender selectedSegment];

    switch (segment)
    {
        case TNArchipelTransportBarPlay:
            [self play];
            break;
        case TNArchipelTransportBarPause:
            [self pause];
            break;
        case TNArchipelTransportBarStop:
            [self stop];
            break;
        case TNArchipelTransportBarDestroy:
            [self destroy];
            break;
        case TNArchipelTransportBarReboot:
            [self reboot];
            break;
    }
}

/*! send play command
    @param aSender the sender of the action
*/
- (IBAction)play:(id)aSender
{
    [self play];
}

/*! send pause command
    @param aSender the sender of the action
*/
- (IBAction)pause:(id)aSender
{
    [self pause];
}

/*! send stop command
    @param aSender the sender of the action
*/
- (IBAction)stop:(id)aSender
{
    [self stop];
}

/*! send destroy command
    @param aSender the sender of the action
*/
- (IBAction)destroy:(id)aSender
{
    [self destroy];
}

/*! send reboot command
    @param aSender the sender of the action
*/
- (IBAction)reboot:(id)aSender
{
    [self reboot];
}

/*! send set autostart command
    @param sender the sender of the action
*/
- (IBAction)setAutostart:(id)aSender
{
    [self setAutostart];
}

/*! send set memory command
    @param aSender the sender of the action
*/
- (IBAction)setMemory:(id)aSender
{
    [self setMemory];
}

/*! send set vCPUs command
    @param aSender the sender of the action
*/
- (IBAction)setVCPUs:(id)aSender
{
    [self setVCPUs];
}

/*! send migrate command
    @param aSender the sender of the action
*/
- (IBAction)migrate:(id)aSender
{
    [self migrate];
}


#pragma mark -
#pragma mark XMPP Controls

/*! ask virtual machine information
*/
- (void)getVirtualMachineInfo
{
    var stanza  = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlInfo}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didReceiveVirtualMachineInfo:)];
}

/*! compute virtual machine answer about its information
*/
- (BOOL)_didReceiveVirtualMachineInfo:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var humanState,
            infoNode            = [aStanza firstChildWithName:@"info"],
            libvirtState        = [infoNode valueForAttribute:@"state"],
            cpuTime             = Math.round(parseInt([infoNode valueForAttribute:@"cpuTime"]) / 60000000000),
            mem                 = parseFloat([infoNode valueForAttribute:@"memory"]),
            maxMem              = parseFloat([infoNode valueForAttribute:@"maxMem"]),
            autostart           = parseInt([infoNode valueForAttribute:@"autostart"]),
            hypervisor          = [infoNode valueForAttribute:@"hypervisor"],
            nvCPUs              = [infoNode valueForAttribute:@"nrVirtCpu"];

        _currentHypervisorJID = hypervisor;

        [fieldInfoMem setStringValue:parseInt(mem / 1024) + @" Mo"];
        [fieldInfoCPUs setStringValue:nvCPUs];
        [fieldInfoConsumedCPU setStringValue:cpuTime + @" min"];

        [stepperCPU setValue:[nvCPUs intValue]];

        if ([_entity XMPPShow] == TNStropheContactStatusOnline)
        {
            [sliderMemory setMinValue:0];
            [sliderMemory setMaxValue:parseInt(maxMem)];
            [sliderMemory setIntValue:parseInt(mem)];
            [sliderMemory setEnabled:YES];
            [stepperCPU setEnabled:YES];
        }
        else
        {
            [sliderMemory setEnabled:NO];
            [sliderMemory setMinValue:0];
            [sliderMemory setMaxValue:100];
            [sliderMemory setIntValue:0];
            [stepperCPU setEnabled:NO];
        }


        [switchAutoStart setEnabled:YES];
        if (autostart == 1)
            [switchAutoStart setOn:YES animated:YES sendAction:NO];
        else
            [switchAutoStart setOn:NO animated:YES sendAction:NO];

        _VMLibvirtStatus = libvirtState;

        [self disableAllButtons];

        [self layoutButtons:libvirtState];

        for (var i = 0; i < [_datasourceHypervisors count]; i++ )
        {
            var item = [_datasourceHypervisors objectAtIndex:i];

            if ([item fullJID] == _currentHypervisorJID)
                [item setSelected:YES];
            else
                [item setSelected:NO];
        }
        [_tableHypervisors reloadData];

        if ([_entity XMPPShow] == TNStropheContactStatusOnline)
        {
            [viewTableHypervisorsContainer setHidden:NO];
            [filterHypervisors setHidden:NO];
        }

        var index               = [[_tableHypervisors selectedRowIndexes] firstIndex];
        if (index != -1)
        {
            var selectedHypervisor  = [_datasourceHypervisors objectAtIndex:index];

            if ([selectedHypervisor fullJID] == _currentHypervisorJID)
                [_migrateButton setEnabled:NO];
        }
    }

    return NO;
}

/*! send play command
*/
- (void)play
{
    var stanza = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{"action": TNArchipelTypeVirtualMachineControlCreate}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didPlay:)];
}

/*! compute the play result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didPlay:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is running"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}

/*! send pause or resume command
*/
- (void)pause
{
    var stanza  = [TNStropheStanza iqWithType:@"set"],
        selector;

    if (_VMLibvirtStatus == VIR_DOMAIN_PAUSED)
    {
        selector = @selector(_didResume:)

        [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
        [stanza addChildWithName:@"archipel" andAttributes:{
            "xmlns": TNArchipelTypeVirtualMachineControl,
            "action": TNArchipelTypeVirtualMachineControlResume}];
    }
    else
    {
        selector = @selector(_didPause:)

        [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
        [stanza addChildWithName:@"archipel" andAttributes:{
            "xmlns": TNArchipelTypeVirtualMachineControl,
            "action": TNArchipelTypeVirtualMachineControlSuspend}];
    }

    [self sendStanza:stanza andRegisterSelector:selector];
}

/*! compute the pause result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didPause:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [self enableButtonsForPaused];
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is paused"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    [self layoutButtons:_VMLibvirtStatus];

    return NO;
}

/*! compute the resume result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didResume:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is resumed"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    [self layoutButtons:_VMLibvirtStatus];

    return NO;
}

/*! send stop command
*/
- (void)stop
{
    var stanza  = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlShutdown}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didStop:)];
}

/*! compute the stop result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didStop:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is shutdowning"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}

/*! send destroy command. but ask for user confirmation
*/
- (void)destroy
{
    var alert = [TNAlert alertWithTitle:@"Unplug Virtual Machine"
                                message:@"Unplug this virtual machine ?"
                                informativeMessage:@"Destroying virtual machine is dangerous. It is equivalent to remove power plug of a real computer"
                                delegate:self
                                 actions:[["Unplug", @selector(performDestroy:)], ["Cancel", @selector(doNotPerformDestroy:)]]];

    [alert runModal];
}

/*! send destroy command
*/
- (void)performDestroy:(id)someUserInfo
{
    var stanza  = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlDestroy}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didDestroy:)];
}

/*! cancel destroy
*/
- (void)doNotPerformDestroy:(id)someUserInfo
{
    [self layoutButtons:_VMLibvirtStatus];
}

/*! compute the destroy result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didDestroy:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is destroyed"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}

/*! send reboot command
*/
- (void)reboot
{
    var stanza  = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlReboot}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didReboot:)];
}

/*! compute the reboot result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didReboot:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Virtual Machine" message:@"Virtual machine is rebooting"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}

/*! send autostart command
*/
- (void)setAutostart
{
    var stanza      = [TNStropheStanza iqWithType:@"set"],
        autostart   = [switchAutoStart isOn] ? "1" : "0";

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlAutostart,
        "value": autostart}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didSetAutostart:)];
}

/*! compute the reboot result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didSetAutostart:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        if ([switchAutoStart isOn])
            [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Autostart" message:@"Autostart has been set"];
        else
            [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Autostart" message:@"Autostart has been unset"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}

/*! send memory command
*/
- (void)setMemory
{
    var stanza      = [TNStropheStanza iqWithType:@"set"],
        memory      = [sliderMemory intValue];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlMemory,
        "value": memory}];
    [self sendStanza:stanza andRegisterSelector:@selector(_didSetMemory:)];
}

/*! compute the memory result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didSetMemory:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"error")
    {
        [self handleIqErrorFromStanza:aStanza];
        [self getVirtualMachineInfo];
    }

    retrun NO;
}

/*! send vCPUs command
*/
- (void)setVCPUs
{
    var stanza      = [TNStropheStanza iqWithType:@"set"],
        cpus        = [stepperCPU value];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlVCPUs,
        "value": cpus}];
    [self sendStanza:stanza andRegisterSelector:@selector(_didSetVCPUs:)];
}

/*! compute the vCPUs result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didSetVCPUs:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"error")
    {
        [self handleIqErrorFromStanza:aStanza];
        [self getVirtualMachineInfo];
    }

    return NO;
}

/*! send migrate command. but ask for a user confirmation
*/
- (void)migrate
{
    var index                   = [[_tableHypervisors selectedRowIndexes] firstIndex],
        destinationHypervisor   = [_datasourceHypervisors objectAtIndex:index];

    if ([destinationHypervisor fullJID] == _currentHypervisorJID)
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Migration" message:@"You can't migrate to the initial virtual machine's hyperviseur." icon:TNGrowlIconError];
        return
    }

    var alert = [TNAlert alertWithTitle:@"Migrate Virtual Machine"
                                message:@"Are you sure you want to migrate this virtual machine ?"
                                informativeMessage:@"You may continue to use this machine while migrating"
                                delegate:self
                                 actions:[["Migrate", @selector(performMigrate:)], ["Cancel", nil]]];

    [alert setUserInfo:destinationHypervisor]
    [alert runModal];

}

/*! send migrate command
*/
- (void)performMigrate:(id)someUserInfo
{
    var destinationHypervisor   = someUserInfo,
        stanza                  = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineControlMigrate,
        "hypervisorjid": [destinationHypervisor fullJID]}];

    [self sendStanza:stanza andRegisterSelector:@selector(_didMigrate:)];
}

/*! compute the migrate result
    @param aStanza TNStropheStanza containing the results
*/
- (BOOL)_didMigrate:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Migration" message:@"Migration has started."];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}


#pragma mark -
#pragma mark Delegates

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    var selectedRow = [[_tableHypervisors selectedRowIndexes] firstIndex];

    if (selectedRow == -1)
    {
        [_migrateButton setEnabled:NO];

        return
    }

    var item = [_datasourceHypervisors objectAtIndex:selectedRow];

    if ([item fullJID] != _currentHypervisorJID)
        [_migrateButton setEnabled:YES];
    else
        [_migrateButton setEnabled:NO];
}

@end