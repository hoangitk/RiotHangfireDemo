﻿<ListQueueItems>
    <div class="commandbar form-inline">
        <CommandButton command="EnqueueEmail" text="Enqueue Email" />
        <CommandButton command="EnqueueReport" text="Enqueue Report" />
        <CommandButton command="ClearQueue" text="Clear Queue" confirm="Are you sure?" />
        <span if={ selectedTasks.length > 0 }>
            <CommandButton command="RequeueItems" cls="btn btn-warning" data={ {ItemIds:selectedTasks} }>
                <span>Requeue { data.ItemIds.length } Tasks</span>
            </CommandButton>
            <span class="input-group">
                <input ref="Log" type="text" class="form-control" />
                <span class="input-group-btn">
                    <CommandButton command="SetQueueItemLog" text="Set Log(s)" cls="btn btn-warning" data={ {ItemIds:selectedTasks} } />
                </span>
            </span>
        </span>
    </div>
    <div if="{ result.Items.length == 0 && !result.PageNumber }" class="lead">
        <i class="fa fa-spinner fa-pulse fa-fw"></i> Loading
    </div>
    <table if="{ result.Items.length > 0 }" class="table table-hover small">
        <thead>
            <tr>
                <th><SelectAll selector=".select-item" /></th>
                <th class="text-center">Id</th>
                <th>Name</th>
                <th>Created</th>
                <th>Started</th>
                <th class="text-right">Completed</th>
                <th class="text-center">Status</th>
                <th>Log</th>
                <th class="text-center">Action</th>
            </tr>
        </thead>
        <tbody>
            <tr each={ item in result.Items }>
                <td><input type="checkbox" onclick={ itemSelected } class="select-item" /></td>
                <td>{ item.Id }</td>
                <td>{ item.Name }</td>
                <td>{ moment(item.Created).fromNow(); }</td>
                <td>
                    <span if={ !!item.Started }>{ moment(item.Started).fromNow(); }</span>
                </td>
                <td class="text-right">
                    <span if={ !!item.Completed }>{ moment(item.Completed).diff(moment(item.Started), 'seconds') } sec(s)</span>
                </td>
                <td class="text-center">
                    <span if="{ item.Status == 'Queued' }" class="label label-warning">{ item.Status }</span>
                    <span if="{ item.Status == 'Running' }" class="label label-info">{ item.Status } <i class="fa fa-spinner fa-pulse fa-fw"></i></span>
                    <span if="{ item.Status == 'Error' }" class="label label-danger">{ item.Status }</span>
                    <span if="{ item.Status == 'Completed' }" class="label label-success">{ item.Status }</span>
                </td>
                <td>
                    <p if={ !!item.Log } class="{ bg-danger:item.Status == 'Error', bg-success:item.Status == 'Completed' }">{ item.Log }</p>
                </td>
                <td class="text-center">
                    <CommandButton command="DeleteQueueItem" confirm="Are you sure?" cls="btn btn-xs btn-danger" data={ {Id:item.Id} }>
                        <i class="fa fa-trash"></i>
                    </CommandButton>
                </td>
            </tr>
        </tbody>
    </table>
    <Pager page-number={ result.PageNumber } page-size={ result.PageSize } total-items={ result.TotalItems } />
    <script>
        var vm = this;
        vm.queryQueueItems = { PageNumber:1, PageSize:10 };
        vm.result = { Items: [] };
        vm.selectedTasks = [];

        function load() {
            jsonRpc("QueryQueueItems", vm.queryQueueItems, function (result) {
                vm.result = result;
                vm.selectedTasks = [];
                vm.update();
            });
        }

        vm.on("mount", function () {
            var pushHub = $.connection.pushHub;
            pushHub.client.push = function (type, data) {
                vm.trigger(type, data);
            };
            $.connection.hub.start();
        });

        vm.on("QueueItems.Changed", function () {
            load();
        });

        vm.on("Pager.Clicked", function (pageNumber) {
            vm.queryQueueItems.PageNumber = pageNumber;
            load();
        });

        vm.itemSelected = function (e) {
            e.item.item.selected = $(e.currentTarget).prop("checked");
            if (e.item.item.selected) {
                vm.selectedTasks.push(e.item.item.Id);
            }
            else {
                var index = vm.selectedTasks.indexOf(e.item.item.Id);
                if (index > -1) vm.selectedTasks.splice(index, 1);
            }
            vm.update();
        };

        load();
    </script>
    <style>
        .lead { margin-top: 14px; }
        .commandbar { margin: 15px 0; }
        .table { margin:0; }
        table p { padding:.5em; margin:0; }
    </style>
</ListQueueItems>
