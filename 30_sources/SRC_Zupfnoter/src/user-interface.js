function init_w2ui(uicontroller) {

    function zoomHarpPreview(size) {
        $("#harpPreview svg").attr('height', size[0]).attr('width', size[1]);
    };

    var zoomlevel = [1400, 2200];

    previews = {
        'tbPreview:tbPrintA3': function () {
            url = uicontroller.$render_a3().$output('datauristring')
            window.open(url)
        },
        'tbPreview:tbPrintA4': function () {
            url = uicontroller.$render_a4().$output('datauristring')
            window.open(url)
        },
        'tbPreview:tbPrintNotes': function () {
            a = window.open();
            //  a.document.write('<style type="text/css">rect.abcref {fill:grey;fill-opacity:0.01}</style>');
            //a.document.write($('#tunePreview').html());
            a.document.write(uicontroller.tune_preview_printer.$get_html())
        }
    }

    perspectives = {
        'tb_perspective:Alle': function () {
            w2ui['layout'].show('left', window.instant);
            w2ui['layout'].hide('bottom', window.instant);
            w2ui['layout'].show('main', window.instant);
            w2ui['layout'].show('preview', window.instant);
            w2ui['layout'].sizeTo('preview', "50%");
            zoomHarpPreview(zoomlevel);
        },
        'tb_perspective:NotenEingabe': function () {
            w2ui['layout'].show('left', window.instant);
            w2ui['layout'].hide('bottom', window.instant);
            w2ui['layout'].show('main', window.instant);
            w2ui['layout'].hide('preview', window.instant);
            w2ui['layout'].sizeTo('preview', "50%");
        },
        'tb_perspective:HarfenEingabe': function () {
            w2ui['layout'].show('left', window.instant);
            w2ui['layout'].hide('bottom', window.instant);
            w2ui['layout'].hide('main', window.instant);
            w2ui['layout'].show('preview', window.instant);
            w2ui['layout'].sizeTo('preview', "100%");
            zoomHarpPreview(zoomlevel);
        },
        'tb_perspective:Noten': function () {
            w2ui['layout'].hide('left', window.instant);
            w2ui['layout'].hide('bottom', window.instant);
            w2ui['layout'].show('main', window.instant);
            w2ui['layout'].hide('preview', window.instant);
            $("#tunePreview").attr('width', '25cm');
        },
        'tb_perspective:Harfe': function () {
            w2ui['layout'].hide('left', window.instant);
            w2ui['layout'].hide('bottom', window.instant);
            w2ui['layout'].hide('main', window.instant);
            w2ui['layout'].show('preview', window.instant);
            w2ui['layout'].sizeTo('preview', "100%");
            zoomHarpPreview(['100%', '98%'])
        },
        'tb_view:0': function () {
            uicontroller.$handle_command("view 0")
        },
        'tb_view:1': function () {
            uicontroller.$handle_command("view 1")
        },
        'tb_view:2': function () {
            uicontroller.$handle_command("view 2")
        },
        'tb_view:3': function () {
            uicontroller.$handle_command("view 3")
        },
        'tb_scale:groß': function () {
            zoomlevel = [1400, 2200];
            zoomHarpPreview(zoomlevel);
        },
        'tb_scale:mittel': function () {
            zoomlevel = [700, 1500];
            zoomHarpPreview(zoomlevel);
        },
        'tb_scale:klein': function () {
            zoomlevel = [400, 800];
            zoomHarpPreview(zoomlevel);
        },
        'tb_scale:fit': function () {
            zoomlevel = ['100%', '100%'];
            zoomHarpPreview(zoomlevel);
        },


        'tbPlay': function () {
            uicontroller.$play_abc('auto');
        },

        'tbRender': function () {
            uicontroller.editor.$resize();
            uicontroller.$render_previews();
        },

        'tb_create': function () {
            openPopup({
                name: 'createNewSheetForm',
                text: w2utils.lang('Create new Sheet'),
                style: 'border: 0px; background-color: transparent;',
                fields: [
                    {field: 'id', type: 'string', required: true, html: {caption: 'X:'}},
                    {
                        field: 'title',
                        type: 'text',
                        required: true,
                        tooltip: "Enter the title of your sheet",
                        html: {caption: w2utils.lang('Title'), attr: 'style="width: 300px"'}
                    }
                ],
                actions: {
                    "Ok": function () {
                        if (this.validate().length == 0) {
                            uicontroller.$handle_command("c " + this.record.id + '"' + this.record.title + '"');
                            w2popup.close();
                        }
                    },
                    "Cancel": function () {
                        w2popup.close();
                    }
                }
            })
        },

        'tb_open': function () {
            uicontroller.$handle_command("dlogin full /");
            uicontroller.$handle_command("dchoose")
        },

        'tb_save': function () {
            uicontroller.$handle_command("dsave")
        },

        'tb_download': function () {
            uicontroller.$handle_command("download_abc")
        },

        'tb_login': function () {
            openPopup({
                name: 'loginForm',
                text: 'Login',
                style: 'border: 0px; background-color: transparent;',
                fields: [
                    {
                        field: 'folder',
                        type: 'text',
                        required: true,
                        html: {caption: 'Folder in Dropbox', attr: 'style="width: 300px"'}
                    },
                ],
                actions: {
                    "login": function () {
                        if (this.validate().length == 0) {
                            uicontroller.$handle_command("dlogin full " + this.record.folder)
                            w2popup.close();
                        }
                    },
                    "reset": function () {
                        this.clear();
                    }
                }
            })
        }
    }

    var pstyle = 'background-color:  #f7f7f7; padding: 0px; overflow:hidden; '; // pajnel style
    var tbstyle = 'background-color: #ffffff; padding: 0px; overflow:hidden; height:30px;'; // toolbar style
    var sbstyle = 'background-color: #ffffff; padding: 0  px; overflow:hidden; height:30px;border-top:1px solid black !important;'; // statusbar style

    var toolbar = {
        id: 'toolbar',
        name: 'toolbar',
        style: tbstyle,
        items: [
            {type: 'button', id: 'tb_home', icon: 'fa fa-home', text: '<span id="lbZupfnoter">Zupfnoter</span>'},
            {type: 'html', html: '<div style="width:25px"/>'},
            {type: 'button', id: 'tb_create', text: 'New', icon: 'fa fa-file-o', tooltip: 'Create new sheet'},
            {
                type: 'button',
                id: 'tb_download',
                text: 'Dl abc',
                icon: 'fa fa-download',
                tooltip: 'download abc to local system'
            },
            {
                type: 'button',
                id: 'tb_login',
                text: 'Login',
                icon: 'fa fa-dropbox',
                tooltip: 'Login in dropbox;\nchoose folder in Dropbox'
            },
            {type: 'button', id: 'tb_open', text: 'Open', icon: 'fa fa-dropbox', tooltip: 'Open ABC file in dropbox'},
            {type: 'button', id: 'tb_save', text: 'Save', icon: 'fa fa-dropbox', tooltip: 'Save ABC file in dropbox'},


            {type: 'spacer'},

            {type: 'break'},
            {
                type: 'menu',
                id: 'tbPreview',
                text: 'Print',
                icon: 'fa fa-print',
                hint: 'Open a preview and printz window',
                items: [
                    {
                        type: 'button',
                        id: 'tbPrintA3',
                        text: 'A3',
                        icon: 'fa fa-file-pdf-o',
                        tooltip: 'Print A3 Harpnotes'
                    },
                    {
                        type: 'button',
                        id: 'tbPrintA4',
                        text: 'A4',
                        icon: 'fa fa-file-pdf-o',
                        tooltip: 'Print A4 Harpnotes'
                    },
                    {type: 'button', id: 'tbPrintNotes', text: 'Tune', icon: 'fa fa-music', tooltip: 'Print Tune'}
                ]
            },

            {type: 'break'},
            {
                type: 'menu',
                id: 'tb_perspective',
                text: 'Perspective',
                icon: 'fa fa-binoculars',
                tooltip: 'set screen perspective',
                items: [
                    {text: 'All', icon: 'fa fa-th-large', id: 'Alle', tooltip: "show all panes"},
                    {
                        text: 'Enter Notes',
                        icon: 'fa fa-music',
                        id: 'NotenEingabe',
                        tooltip: "editor and notes\napplicable to enter notes"
                    },
                    {
                        text: 'Enter Harp',
                        icon: 'fa fa-file-picture-o',
                        id: 'HarfenEingabe',
                        tooltip: "editor and harpnotes\napplicaple to tweak the notes for harp"
                    },
                    {text: 'Tune"', icon: 'fa fa-music', id: 'Noten', tooltip: "notes only"},
                    {
                        text: 'Harp',
                        icon: 'fa fa-file-picture-o',
                        id: 'Harfe',
                        tooltip: "harpnotes only\napplicable to proofread harpnotes"
                    }
                ]
            },
            {type: 'break', id: 'break0'},
            {
                type: 'menu',
                id: 'tb_view',
                text: 'Extract',
                icon: 'fa fa-shopping-basket',
                tooltip: "Choose extract",
                items: [
                    {text: 'Extract 0', icon: 'fa fa-tags', id: "0"},
                    {text: 'Extract 1', icon: 'fa fa-tags', id: "1"},
                    {text: 'Extract 2', icon: 'fa fa-tags', id: "2"},
                    {text: 'Extract 3', icon: 'fa fa-tags', id: "3"}
                ]
            },
            {type: 'break'},
            {type: 'button', id: 'tbRender', text: 'Render', icon: 'fa fa-refresh', tooltip: 'Render previews'},
            {type: 'button', id: 'tbPlay', text: 'Play', icon: 'fa fa-play', tooltip: 'Play music'},
            {
                type: 'menu', text: 'Help', id: 'tbHelp', icon: 'fa fa-question', tooltip: 'Get help', items: [
                {text: 'Videos', icon: 'fa fa-tags', id: "tbTutorials", tooltip: 'Open the video tutorials on youtube'},
                {
                    text: 'abc Tutorial',
                    icon: 'fa fa-tags',
                    id: "tbAbcTutorial",
                    tooltip: 'Open an ABC tutorial (in German)'
                },
                {text: 'Manual', icon: 'fa fa-tags', id: "tbManual", tooltip: 'Open the user manual'},
                {text: 'Homepage', icon: 'fa fa-tags', id: "tbHomepage", tooltip: 'Open Zupfnoter website'},
                {text: ''},
                {
                    text: 'Reference',
                    icon: 'fa fa-tags',
                    id: "tbReference",
                    tooltip: 'Open a new Zupfnoter window\nwith the reference page'
                },
                {
                    text: 'Demo',
                    icon: 'fa fa-tags',
                    id: "tbDemo",
                    tooltip: 'Open a demo sheet\n(Ich steh an deiner Kripen hier)'
                }
            ]
            }
        ],

        onClick: function (event) {
            // handle perspectives
            if (perspectives[event.target]) {
                perspectives[event.target]();
                if (event.subItem) {
                    event.item.text = event.subItem.text
                }
            }

            // handle previews
            if (previews[event.target]) {
                previews[event.target]();
            }

            config_event = event.target.split(":")
            if (config_event[0] == 'config') {
                if (config_event[1]) {
                    uicontroller.$handle_command("addconf " + event.target.split(":")[1])
                }
            }
            if (event.target == "tb_home") {
                window.open("https://www.zupfnoter.de")
            }
            if (event.target == "tbHelp:tbTutorials") {
                window.open("https://www.youtube.com/channel/UCNwzBbzhyHJOn9eHHl_guHg")
            }
            if (event.target == "tbHelp:tbAbcTutorial") {
                window.open("http://penzeng.de/Geige/Abc.htm")
            }
            if (event.target == "tbHelp:tbHomepage") {
                window.open("http://www.zupfnoter.de")
            }
            if (event.target == "tbHelp:tbManual") {
                window.open("https://github.com/bwl21/zupfnoter/blob/master/README.md")
            }
            if (event.target == "tbHelp:tbReference") {
                window.open("?mode=demo&load=public/demos/3015_reference_sheet.abc")
            }
            if (event.target == "tbHelp:tbDemo") {
                window.open("?mode=demo&load=public/demos/21_Ich_steh_an_deiner_krippen_hier.abc")
            }
        }
    }

    var editor_toolbar = {
        id: 'toolbar',
        name: 'editor-toolbar',
        style: tbstyle,
        items: [
            {
                type: 'menu', text: "Add Config", id: 'config', icon: 'fa fa-gear', tooltip: "configure your sheet",
                items: [
                    {id: 'title', tooltip: "insert a title for the \ncurrent extract"},
                    {id: 'voices', tooltip: "specify voices to \nbe shown in current extract"},
                    {text: 'flowlines', tooltip: "specify which voices \nshow the flowline"},
                    {text: 'jumplines', tooltip: "specify which voices \nshow the jumplines"},
                    {text: 'repeatsigns', tooltip: "specify which voices\nshow repeat signs instead of jumplines"},
                    {text: 'synchlines', tooltip: "specify which voices\nare connected by synchronization lines"},
                    {
                        text: 'layoutlines',
                        tooltip: "specify which voides\nare considered to compute \nvertical spacing"
                    },
                    {text: 'subflowlines', tooltip: "specify which voices \nshow the subflowlines"},
                    {},

                    {text: 'legend', tooltip: "specify details for legend"},
                    {text: 'lyrics', tooltip: "specify details for lyrics"},
                    {id: 'notes', text: 'page annotation', tooltip: "enter a page bound annotation"},
                    {text: ''},

                    {text: 'nonflowrest', tooltip: "specify if rests are shown outside of flowlines"},
                    {text: 'startpos', tooltip: "specify the vertical start position of the notes"},
                    {
                        text: 'countnotes',
                        tooltip: "specify which voices\n shwow countnotes\n and appeareance of the same"
                    },
                    {
                        text: 'barnumbers',
                        tooltip: "specify which voices\n shwow bar numbers\n and appeareance of the same"
                    },
                    {text: 'layout', tooltip: "specify laoyut details \n(e.g. size of symbols)"},
                    {
                        text: 'stringnames',
                        tooltip: "specify output of stringnames.\n Stringnames help to tune the instrument"
                    },
                    {text: ''},
                    {text: 'produce', tooltip: "specify which extracts shall be saved as PDF"},
                    {
                        id: 'annotations',
                        text: 'annotation template',
                        tooltip: "specify temmplate for\n note bound annotations"
                    },
                    {text: ''},
                    {text: 'stringnames.full', tooltip: "specify full details for stringnams"},
                    {text: 'repeatsigns.full', tooltip: "specify all details for repeat signs"},
                    {text: 'barnumbers.full', tooltip: "specify all details for bar numbers"},
                    {text: ''},
                    {id: 'printer', text: 'Printer adapt', tooltip: "specify printer adaptations details \n(e.g. offsets)"},
                    {
                        id: 'restpos_1.3',
                        text: 'rests as V 1.3',
                        tooltip: "configure positioning of rests\ncompatible to version 1.3"
                    },
                    {text: 'xx', tooltip: "inject the default configuration (for development use only)"},
                ]
            },
            {
                type: 'menu',
                text: "Edit Config",
                id: 'edit_config',
                icon: 'fa fa-pencil',
                tooltip: "Edit configuration with forms",
                items: [
                    {id: 'global', text: 'global settings', tooltip: "edit global settings for the current song"},
                    {id: 'basic_settings', text: 'basic settings', tooltip: "Edit basic settings of extract"},
                    {id: 'layout', text: 'layout', tooltip: "Edit layouyt paerameters"},
                    {id: 'lyrics', text: 'lyrics', tooltip: "edit settings for lyrics\nin current extract"},
                    {
                        id: 'barnumbers_countnotes',
                        text: 'barnumbers and countnotes',
                        tooltip: "edit barnumbers or countnotes"
                    },
                    {
                        id: 'notes',
                        text: 'page annotation',
                        tooltip: "edit settings for sheet annotations\nin current extract"
                    },
                    {id: 'printer', text: 'Printer adapt', tooltip: "Edit printer correction paerameters"},
                    {},
                    {id: 'extract_current', text: 'current extract', tooltip: "Edit current extract"}
                ]
            },
            {
                type: 'menu',
                text: "Insert Addon",
                id: 'add_snippet',
                items: [
                    {id: 'goto', text: 'Goto', tooltip: "Add a Jump"},
                    {id: 'shifter', text: 'Shift', tooltip: "Add a shift"},
                    {},
                    {id: 'draggable', text: 'Draggable', tooltip: "Add a draggable mark"},
                    {},
                    {id: 'annotation', text: 'Annotation', tooltip: "Add an annotation"},
                    {id: 'annotationref', text: 'Annotation Ref', tooltip: "Add a predefined annotation"},
                    {},
                    {id: 'jumptarget', text: 'Jumptarget', tooltip: "Add a Jumptarget"}
                ],
                icon: 'fa fa-gear',
                tooltip: "Insert addon at cursor position",
            },
            {
                type: 'button',
                text: "Edit Addon",
                id: 'edit_snippet',
                icon: 'fa fa-pencil',
                tooltip: "Edit addon on cursor position"
            }
        ],

        onClick: function (event) {
            // handle perspectives
            if (perspectives[event.target]) {
                perspectives[event.target]();
                if (event.subItem) {
                    event.item.text = event.subItem.text
                }
            }

            // handle previews
            if (previews[event.target]) {
                previews[event.target]();
            }

            config_event = event.target.split(":")
            if (['config'].includes(config_event[0])) {
                if (config_event[1]) {
                    uicontroller.$handle_command("addconf " + event.target.split(":")[1])
                }
            }

            config_event2 = event.target.split(":")
            if (['edit_config'].includes(config_event2[0])) {
                if (config_event2[1]) {
                    w2ui.layout_left_tabs.click('configtab');
                    uicontroller.$handle_command("editconf " + config_event2[1])
                }
            }

            config_event3 = event.target.split(":")
            if (['edit_snippet'].includes(config_event3[0])) {
                w2ui.layout_left_tabs.click('abcEditor');
                uicontroller.$handle_command("editsnippet")
            }

            config_event4 = event.target.split(":")
            if (['add_snippet'].includes(config_event4[0])) {
                if (config_event4[1]) {
                    w2ui.layout_left_tabs.click('abcEditor');
                    uicontroller.$handle_command("addsnippet " + config_event4[1])
                }
            }
        }

    }
    var statusbar = {
        id: 'statusbarbar',
        name: 'statusbar',
        style: sbstyle,
        items: [
            {
                type: 'button',
                id: 'sb_cursorposition',
                text: '<div style="padding: 0px !important;"><span class="editor-status-position" "></span></div>'
            },
            {
                type: 'button',
                id: 'sb_tokeninfo',
                size: '50px',
                text: '<div style="padding: 0px !important;"><span class="editor-status-tokeninfo" "></span></div>'
            },
            {
                type: 'button',
                id: 'sb_dropbox-status',
                text: '<div style="padding: 0px !important;"><span class="dropbox-status" "></span></div>'
            },
            {
                type: 'button',
                id: 'sb_loglevel',
                text: '<div style="padding: 0px !important;"><span class="sb-loglevel" "></span></div>'
            },
            {type: 'spacer'},
            {
                type: 'button',
                id: 'sb_confkey',
                text: '<div style="padding: 0px !important;"><span class="mouseover-conf-key"></span></div>'
            },

        ],

        onClick: function (event) {
            sb_event = event.target.split(":")
            if (sb_event[0] == 'sb_loglevel') {uicontroller.$toggle_console()}
        }
    }


    var editortabshtml = '<div id="editortabspanel" style="height:100%">'
            + '<div id="abcEditor" class="tab" style="height:100%;"></div>'
            + '<div id="abcLyrics" class="tab" style="height:100%;"></div>'
            + '<div id="configtab" class="tab" style="height:100%;"></div>'
            + '</div>'
        ;

    var editortabsconfig = {
        name: 'editortabs',
        active: 'abcEditor',
        tabs: [
            {id: 'abcEditor', text: w2utils.lang('abc')},
            {id: 'abcLyrics', text: w2utils.lang('lyrics')},
            {id: 'configtab', text: w2utils.lang('Configuration')}
        ],
        onClick: function (event) {
            $('#editortabspanel .tab').hide();
            $('#' + event.target).show();
            $('#' + event.target).resize();
        }
    };

    var zoomtabsconfig = {
        name: 'zoomtabs',
        active: 'groß',
        tabs: [
            {text: 'large', id: 'groß', icon: 'fa fa-expand', tooltip: "large view\nto see all details"},
            {
                text: 'medium',
                id: 'mittel',
                icon: 'fa fa-dot-circle-o',
                tooltip: "medium view\nmost commonly used\nautoscroll works"
            },
            {text: 'small', id: 'klein', icon: 'fa fa-compress', tooltip: "small view\nto get an overview"},
            {text: 'fit', id: 'fit', icon: 'fa fa-arrows-alt', tooltip: "fit to viewport"}

            // {id: 'groß', text: w2utils.lang('large'), icon: ''},
            // {id: 'mittel', text: w2utils.lang('medium')},
            // {id: 'klein', text: w2utils.lang('small')},
            // {id: 'fit', text: w2utils.lang('fit')}
        ],
        onClick: function (event) {
            $('#harpPreview .tab').hide();
            perspectives['tb_scale:' + event.target]();
            $('#harpPreview #' + event.target).show();
        }
    };


    $('#statusbar-layout').w2layout(
        {
            name: 'statusbar-laoyut',
            panels: [
                //{type: 'main', id: 'statusbar', resizable: false, style: pstyle, content: '<div id="statusbar" style="overflow:hidden;border: 1pt solid #000000;" class="zn-statusbar" >statusbar</div>',  hidden: false}
                {
                    type: 'main',
                    id: 'statusbar',
                    resizable: false,
                    style: pstyle,
                    content: '',
                    toolbar: statusbar,
                    hidden: false
                }
            ]
        }
    );

    $('#layout').w2layout({
        name: 'layout',
        panels: [
            {type: 'top', id: 'foobar', size: 30, resizable: false, content: '', toolbar: toolbar, hidden: false},  // Toolbar
            {
                type: 'left',
                size: '50%',
                hidden: false,
                resizable: true,
                toolbar: editor_toolbar,
                style: pstyle,
                tabs: editortabsconfig,
                content: editortabshtml
            },
            {
                type: 'main',
                style: pstyle,
                overflow: 'hidden',
                //tabs: editortabsconfig,
                content: '<div id="tunePreview"  style="height:100%;" ></div>'
            },
            {
                type: 'preview',
                size: '50%',
                resizable: true,
                hidden: false,
                style: pstyle,
                tabs: zoomtabsconfig,
                content: '<div id="harpPreview" style="height:100%"></div>'
            },
            {
                type: 'right',
                size: 200,
                resizable: true,
                hidden: true,
                style: pstyle,
                content: '<div id="configEditor"></div>'
            },
            {
                type: 'bottom',
                size: '10%',
                resizable: true,
                hidden: true,
                style: pstyle,
                content: '<div id="commandconsole"></div>'
            }
        ]

    });

    w2ui['layout'].refresh();
    $('#editortabspanel .tab').hide();
    $('#abcEditor').show();

    w2ui['layout'].onResize = function (event) {
        uicontroller.editor.$resize();
    };
}
;


function set_tbitem_caption(item, caption) {
    w2ui.layout_top_toolbar.set(item, {text: caption});
}

function update_systemstatus_w2ui(systemstatus) {
    $(".dropbox-status").html(systemstatus.dropbox);

    set_tbitem_caption('tb_view', systemstatus.view);

    if (systemstatus.music_model == 'changed') {
        $("#tb_layout_top_toolbar_item_tb_save .w2ui-tb-caption").css("color", "red")
    } else {
        $("#tb_layout_top_toolbar_item_tb_save .w2ui-tb-caption").css("color", "")
    }
    ;

    $(".sb-loglevel").html('Loglevel: ' + systemstatus.loglevel);
}

function update_error_status_w2ui(errors){
    w2alert(errors, w2utils.lang("Errors occurred"))
}

function update_editor_status_w2ui(editorstatus) {
    $(".editor-status-position").html(editorstatus.position);
    $(".editor-status-tokeninfo").html(editorstatus.tokeninfo);
    if (editorstatus.token.type.startsWith("zupfnoter.editable")) {
        w2ui.layout_left_toolbar.enable('edit_snippet')
    }
    else {
        w2ui.layout_left_toolbar.disable('edit_snippet')
    }

    // todo: implement a proper inhibit manager
    if (editorstatus.token.type.startsWith("zupfnoter.editable.before")) {
        w2ui.layout_left_toolbar.enable('add_snippet');
        w2ui.layout_left_toolbar.enable('add_snippet:annotation', 'add_snippet:annotationref', 'add_snippet:jumptarget', 'add_snippet:draggable', 'add_snippet:shifter');

        w2ui.layout_left_toolbar.disable('edit_snippet');
    }
    else {
        w2ui.layout_left_toolbar.disable('add_snippet')
    }

    if (editorstatus.token.type.startsWith("zupfnoter.editable.beforeBar")) {
        w2ui.layout_left_toolbar.disable('add_snippet:annotation', 'add_snippet:annotationref', 'add_snippet:jumptarget', 'add_snippet:draggable', 'add_snippet:shifter');
    }


    w2ui.layout_left_toolbar.refresh()
}

function update_mouseover_status_w2ui(element_info) {
    $(".mouseover-conf-key").html(element_info);
}

function update_play_w2ui(status) {
    if (status == "start") {
        w2ui.layout_top_toolbar.set('tbPlay', {text: "Stop", icon: "fa fa-stop"})
    }
    else {
        w2ui.layout_top_toolbar.set('tbPlay', {text: "Play", icon: "fa fa-play"})
    }
}
;

function openPopup(theForm) {

    if (!w2ui[theForm.name]) {
        $().w2form(theForm);
    }
    $().w2popup('open', {
        title: theForm.text,
        body: '<div id="form" style="width: 100%; height: 100%;"></div>',
        style: 'padding: 15px 0px 0px 0px',
        width: 500,
        height: 300,
        showMax: true,
        onToggle: function (event) {
            $(w2ui[theForm.name].box).hide();
            event.onComplete = function () {
                $(w2ui[theForm.name].box).show();
                w2ui[theForm.name].resize();
            }
        },
        onOpen: function (event) {
            event.onComplete = function () {
                // specifying an onOpen handler instead is equivalent to specifying an onBeforeOpen handler, which would make this code execute too early and hence not deliver.
                $('#w2ui-popup #form').w2render(theForm.name);
            }
        }
    });
}

if (String.prototype.repeat == undefined) {
    String.prototype.repeat = function (n) {
        n = n || 1;
        return Array(n + 1).join(this);
    }
}

