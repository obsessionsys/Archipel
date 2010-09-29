/*
 * TNWindowDownloadQueue.j
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

TNArchipelTypeHypervisorVMCasting                   = @"archipel:hypervisor:vmcasting"
TNArchipelTypeHypervisorVMCastingDownloadQueue      = @"downloadqueue";


@implementation TNWindowDownloadQueue : CPWindow
{
    @outlet CPScrollView            mainScrollView;

    TNStropheContact                entity  @accessors;

    CPTableView                     _mainTableView;
    CPTimer                         _timer;
    TNTableViewDataSource           _dlDatasource;
}

- (void)awakeFromCib
{
    _dlDatasource = [[TNTableViewDataSource alloc] init];

    _mainTableView = [[CPTableView alloc] initWithFrame:[mainScrollView bounds]];
    [_mainTableView setAutoresizingMask:CPViewHeightSizable | CPViewWidthSizable];
    [_mainTableView setUsesAlternatingRowBackgroundColors:YES];
    [_mainTableView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];

    var columnIdentifier = [[CPTableColumn alloc] initWithIdentifier:@"name"],
        columnSize = [[CPTableColumn alloc] initWithIdentifier:@"totalSize"],
        columnPercentage = [[CPTableColumn alloc] initWithIdentifier:@"percentage"];

    [[columnIdentifier headerView] setStringValue:@"Name"];

    [[columnSize headerView] setStringValue:@"Total Size"];

    [[columnPercentage headerView] setStringValue:@"Percentage"];

    [_mainTableView addTableColumn:columnIdentifier];
    [_mainTableView addTableColumn:columnSize];
    [_mainTableView addTableColumn:columnPercentage];

    [_dlDatasource setTable:_mainTableView];
    [_dlDatasource setSearchableKeyPaths:[@"name", @"totalSize", @"percentage"]];

    [_mainTableView setDataSource:_dlDatasource];

    [mainScrollView setAutohidesScrollers:YES];
    [mainScrollView setBorderedWithHexColor:@"#C0C7D2"]
    [mainScrollView setDocumentView:_mainTableView];
    [_mainTableView reloadData];
}

- (void)makeKeyAndOrderFront:(id)sender
{
    [self getDownloadQueue:nil];
    if (!_timer)
        _timer = [CPTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(getDownloadQueue:) userInfo:nil repeats:YES];
    [super makeKeyAndOrderFront:sender];
}

- (void)performClose:(id)sender
{
    [_timer invalidate];
    _timer = nil;
    [super performClose:sender];
}

- (void)getDownloadQueue:(CPTimer)aTimer
{
    var stanza = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeHypervisorVMCasting}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeHypervisorVMCastingDownloadQueue}];


    [[self entity] sendStanza:stanza andRegisterSelector:@selector(didReceiveDownloadQueue:) ofObject:self];
}

- (void)didReceiveDownloadQueue:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var downloads = [aStanza childrenWithName:@"download"];

        [_dlDatasource removeAllObjects];

        for (var i = 0; i < [downloads count]; i++)
        {
            var download    = [downloads objectAtIndex:i],
                identifier  = [download valueForAttribute:@"uuid"],
                name        = [download valueForAttribute:@"name"],
                percentage  = Math.round(parseFloat([download valueForAttribute:@"percentage"])),
                totalSize   = Math.round(parseFloat([download valueForAttribute:@"total"])),
                dl          = [TNDownload downloadWithIdentifier:identifier name:name totalSize:totalSize percentage:percentage];

            [_dlDatasource addObject:dl];
        }

        [_mainTableView reloadData];
    }
}
@end
