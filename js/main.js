// http://stackoverflow.com/a/2548133/25507
if (typeof String.prototype.endsWith !== 'function') {
    String.prototype.endsWith = function(suffix) {
        return this.indexOf(suffix, this.length - suffix.length) !== -1;
    };
}

function escapeHtml(s)
{
    return s.replace(/&/g, '&amp;').replace(/>/g, '&gt;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
}

function locationHashNoQuery()
{
    return location.hash.replace(/\?.*/, '');
}

function currentQuery()
{
    var query = '';
    query += versions.asQuery();
    if (query) {
        return '?' + query;
    } else {
        return '';
    }
}

function updateNav()
{
    // Update nav links to use the current version query.
    $("a[data-base-href]").each(function () {
        $(this).attr('href', $(this).attr('data-base-href') + currentQuery());
    });
}

function setActiveNav(active_nav_route)
{
    $(".nav li").removeClass("active");
    if (active_nav_route) {
        $(".nav a[data-base-href='" + active_nav_route + "']").parent().addClass("active");
    }
}

function scrollToId()
{
    var $hash = $(locationHashNoQuery().replace(/\//g, '\\/'));
    if ($hash.length) {
        $("#content-container").scrollTop($("#content-container").scrollTop() + $hash.offset().top);
    }
}

function enableExpandCollapseAll()
{
    $(".expand-all").addClass('fa fa-toggle-down')
        .attr('title', 'Expand All');
    $(".collapse-all").addClass('fa fa-toggle-up')
        .attr('title', 'Collapse All');
    $(".expand-all, .collapse-all").addClass('clickable')
        .click(function() {
            $($(this).attr('data-target')).find('.collapse').collapse($(this).hasClass('expand-all') ? 'show' : 'hide');
        });
}

function showCollapsed(html_id, disable_transitions)
{
    if (html_id[0] != '#') {
        html_id = '#' + html_id;
    }

    // Hack: If requested, temporarily disable transitions.  Bootstrap's default
    // transition is 0.35s, so we do just a bit longer.
    // Based on http://stackoverflow.com/a/22428493/25507
    if (disable_transitions) {
        $(html_id).addClass('disable-transition');
        setTimeout(function() { $(html_id).removeClass('disable-transition'); }, 400);
    }

    $(html_id).collapse('show');
    // Hack: Update "collapsed" class, since Bootstrap doesn't seem to do it
    // for us (unless, presumably, we use data-parent for full-blown accordion
    // behavior, and I don't really want to do that).
    $("[data-target=" + html_id + "]").removeClass('collapsed');
}

/**Gets the HTML IDs of currently expanded collapsed items. */
function getExpandedIds()
{
    return $.map($(".collapse.in"), function(n, i) {
        return n.id;
    });
}

function expandIds(id_list, disable_transitions)
{
    for (var i = 0; i < id_list.length; i++) {
        showCollapsed(id_list[i], disable_transitions);
    }
}

function makeStickyHeader($header, $container)
{
    var $sticky = $header.clone();
    $sticky.attr('id', $header.attr('id') + '-sticky')
        .addClass('sticky')
        .css('width', $header.width())
        .hide()
        .insertBefore($header);
    $container.scroll(function() {
        // Generic approach.  Lets the full header skip up a bit before the sticky header appears.
        //if ($container.scrollTop() >= $sticky.outerHeight())
        if ($header.children('h1').offset().top < $sticky.children('h1').offset().top) {
            $sticky.show();
            $header.css('visibility', 'hidden');
        } else {
            $sticky.hide();
            $header.css('visibility', '');
        }
    });
    $(window).resize(function() {
        $sticky.css('width', $header.width());
    });
}

var options = {
    imgSize: 48
};

///Simplistic title-case function that capitalizes the beginning of every word.
function toTitleCase(s)
{
    var never_capitalize = {
        // Fix problems like "Berserker's"
        "s":true,
        // Prepositions and internal articles
        "of":true,
        "the":true
    };
    s = s.replace(/\b([a-z])([a-z]+)/g, function(match, p1, p2) { return never_capitalize[match] ? match : (p1.toUpperCase() + p2); });
    // Force the first word to be capitalized, even if it's "of" or "the"
    return s[0].toUpperCase() + s.slice(1);
}

function to_chn_talent_categories(s)
{
	if (tome[versions.current].chn_talent_categories[s] != undefined) return tome[versions.current].chn_talent_categories[s];
	return s;
}

///ToME-specific function that makes a ToME ID a valid and standard HTML ID
function toHtmlId(s)
{
    // For now, only replace characters known to cause issues.
    return s.toLowerCase().replace(/[':\/]/, '_');
}

///As toHtmlId, but leaves slashes intact, for code like talents that
///legitimately uses them (e.g., "spells/fire").
function toUnsafeHtmlId(s)
{
	return s.toLowerCase().replace(/[':]/, '_');
}

/**Given an object, return a new object that indexes the object's properties by
 * HTML ID.
 *
 * For example, if classes = { 'WARRIOR': { 'short_name': 'WARRIOR', ... }, ...},
 * then indexByHtmlId(classes, 'short_name') will return
 * { 'warrior': { 'short_name': 'WARRIOR', ... }, ...}
 */
function indexByHtmlId(obj, property) {
    return _.object(_.map(obj, function(elem) { return [ toHtmlId(elem[property]), elem ]; }));
}

/**Marks up inline links to the ToME wiki */
function markupHintLinks() {
    // TODO: Try FontAwesome instead. I think it might look nicer than glyphicon here.
    $('.hint-link[target!=_blank]').append(' <span class="fa fa-external-link"></span>')
        .attr('target', '_blank');
}

function enableTalentTooltips() {
    $(".html-tooltip").tooltip({ html: true });
    $(".variable, .talent-variable, .stat-variable")
        .attr('data-toggle', 'tooltip')
        .tooltip({ html: true });
}

///Iterates over properties, sorted. Based on http://stackoverflow.com/a/9058854/25507.
Handlebars.registerHelper('eachProperty', function(context, options) {
    var ret = "",
        keys = _.keys(context || {});
    keys.sort();
    for (var i = 0; i < keys.length; i++) {
        ret = ret + options.fn({key: keys[i], value: context[keys[i]]});
    }
    return ret;
});

/**Renders a partial, with additional arguments. Based on http://stackoverflow.com/a/14618035/25507
 *
 * Usage: Arguments are merged with the context for rendering only
 * (non destructive). Use `:token` syntax to replace parts of the
 * template path. Tokens are replace in order.
 *
 * USAGE: {{$ 'path.to.partial' context=newContext foo='bar' }}
 * USAGE: {{$ 'path.:1.:2' replaceOne replaceTwo foo='bar' }}
 */
Handlebars.registerHelper('$', function (partial) {
    var values, opts, done, value, context;
    if (!partial) {
        console.error('No partial name given.');
    }
    values = Array.prototype.slice.call(arguments, 1);
    opts = values.pop().hash;
    while (!done) {
        value = values.pop();
        if (value) {
            partial = partial.replace(/:[^\.]+/, value);
        } else {
            done = true;
        }
    }
    partial = Handlebars.partials[partial];
    if (!partial) {
        return '';
    }
    context = _.extend({}, opts.context || this, _.omit(opts, 'context', 'fn', 'inverse'));
    return new Handlebars.SafeString(partial(context));
});

Handlebars.registerHelper('to_chn_talent_categories', function(context, options) {
    return to_chn_talent_categories(context);
});

Handlebars.registerHelper('toTitleCase', function(context, options) {
    return toTitleCase(context);
});

Handlebars.registerHelper('toWikiLink', function(context, options) {
    s = context.toLowerCase();
	s = s.replace(/ /g, "_")
	return s.substring(0, 1).toUpperCase() + s.substring(1);
});

Handlebars.registerHelper('toDecimal', function(context, places, options) {
   return context.toFixed(places || 2);
});

// ToME-specific function that makes a ToME ID a valid and standard HTML ID
Handlebars.registerHelper('toHtmlId', function(context, options) {
    return toHtmlId(context);
});

// ToME-specific function that tries to make a name or ID into a te4.org wiki page name
Handlebars.registerHelper('toWikiPage', function(context, options) {
   return toTitleCase(context).replace(' ', '_');
});

Handlebars.registerHelper('tag', function(context, options) {
    return tome[versions.current].tag;
});

Handlebars.registerHelper('currentQuery', function(context, options) {
    return currentQuery();
});

Handlebars.registerHelper('opt', function(opt_name) {
    return options[opt_name];
});

Handlebars.registerHelper('labelForChangeType', function(type) {
    var css_class = { "changed": "info", "added": "success", "removed": "danger" },
        text = { "changed": "修改了", "added": "新增了", "removed": "移除了" };
    return '<span class="label label-' + css_class[type] + '">' + text[type] + ':</span>';
});

Handlebars.registerHelper('stat', function(desc, value) {
    var value_html;
    if (!value) {
        value_html = '<span class="stat-neutral">+0</span>';
    } else if (value > 0) {
        value_html = '<span class="stat-bonus">+' + value + '</span>';
    } else {
        value_html = '<span class="stat-penalty">' + value + '</span>';
    }
    return new Handlebars.SafeString("<dt>" + desc + ":</dt><dd>" + value_html + "</dd>");
});

function configureImgSize() {
    options.imgSize = parseInt($.cookie("imgSize") || options.imgSize);

    function showImgSizeSelection() {
        $('.option-img-size').removeClass("selected");
        $('.option-img-size[data-img-size="' + options.imgSize + '"]').addClass("selected");
    }

    function changeImgSize(old_size, new_size) {
        $("img").each(function(n, e) {
            if ($(this).attr("width") == old_size) {
                $(this).attr("width", new_size)
                    .attr("height", new_size)
                    .attr("src", $(this).attr("src").replace(old_size.toString(), new_size.toString()));
            }
        });
    }

    showImgSizeSelection();

    $(".option-img-size").click(function(e) {
        var old_size = options.imgSize;
        options.imgSize = parseInt($(this).attr("data-img-size"));
        showImgSizeSelection();
        changeImgSize(old_size, options.imgSize);
        $.cookie('imgSize', options.imgSize, { expires: 365, path: '/' });
    });
}

// ToME versions.
var versions = (function() {
    var $_dropdown,
        prev_expanded;

    function onChange() {
        $_dropdown.val(versions.current);

        // Hack: If version changes, then save what IDs are expanded so
        // we can restore their state after we recreate them for the
        // new version, and also assume that the side nav needs to be
        // refreshed.  (This is a hack because it ties the versions
        // module too closely to our DOM organization.)
        prev_expanded = getExpandedIds();
        $("#side-nav").html("");

        updateNav();
    }

    var versions = {
        DEFAULT: '1.2.4',
        //ALL: [ '1.1.5', '1.2.0', '1.2.1', '1.2.2', '1.2.3', 'master' ],
		ALL: ['1.2.3','1.2.4'],
        DISPLAY: { '1.2.3': '1.2.3中文' , '1.2.4': '1.2.4中文'},

        name: function(ver) {
            return versions.DISPLAY[ver] || ver;
        },

        isMajor: function(ver) {
            return ver.endsWith('.0');
        },

        asMajor: function(ver) {
            return ver.replace(/\.\d+$/, '');
        },

        update: function(query) {
            query = query || {};
            query.ver = query.ver || versions.DEFAULT;
            if (versions.current != query.ver) {
                versions.current = query.ver;
                onChange();
            }
        },

        updateFinished: function() {
            if (prev_expanded) {
                expandIds(prev_expanded, true);
                prev_expanded = null;
            }
        },

        asQuery: function() {
            if (versions.current == versions.DEFAULT) {
                return '';
            } else {
                return 'ver=' + versions.current;
            }
        },

        // Lists available versions in the given <option> element(s).
        list: function($el, $container) {
            var html;
            if (versions.ALL.length < 2) {
                ($container || $el).hide();
            } else {
                html = '';
                for (var i = 0; i < versions.ALL.length; i++) {
                    html += '<option value="' + versions.ALL[i] + '"';
                    if (versions.ALL[i] == versions.DEFAULT) {
                        html += ' selected';
                    }
                    html += '>' + versions.name(versions.ALL[i]) + '</option>';
                }
                ($container || $el).removeClass("hidden").show();
                $el.html(html);
            }
        },

        // Listens for version change events in the given <option> element(s).
        listen: function($el) {
            $el.change(function() {
                versions.current = $(this).val();
                onChange();
                hasher.setHash(locationHashNoQuery() + currentQuery());
            });
        },

        init: function($el, $container) {
            $_dropdown = $el;
            versions.list($el, $container);
            versions.listen($el);
            updateNav();
        }
    };
    versions.current = versions.DEFAULT;
    return versions;
}());

var routes,
    load_nav_data_handler,
    base_title = document.title;

function initializeRoutes() {
    routes = {

        // Default route.  We currently just have talents.
        default_route: crossroads.addRoute(':?query:', function(query) {
            versions.update(query);
            document.title = base_title;
            setActiveNav();

            $("#content").html($("#news").html());
            $("#side-nav").html('');
        }),

        // Updates for previous versions of the site.
        reroute1: crossroads.addRoute('changes/talents?ver=1.2.0dev', function() {
            hasher.replaceHash('changes/talents?ver=master');
        }),

        changes_talents: crossroads.addRoute('changes/talents:?query:', function(query) {
            routes.talents.matched.dispatch(query);

            $("#content-container").scrollTop(0);
            loadDataIfNeeded('changes.talents', function() {
                document.title += tome[versions.current].majorVersion + '新特性';
                $("#content").html(listChangesTalents(tome));

                enableTalentTooltips();

                versions.updateFinished();
            });
        }),

        recent_changes_talents: crossroads.addRoute('recent-changes/talents:?query:', function(query) {
            // FIXME: Remove duplication with changes_talents route
            routes.talents.matched.dispatch(query);

            $("#content-container").scrollTop(0);
            loadDataIfNeeded('recent-changes.talents', function() {
                document.title += tome[versions.current].version + '新特性';
                $("#content").html(listRecentChangesTalents(tome));

                enableTalentTooltips();

                versions.updateFinished();
            });
        }),

        talents: crossroads.addRoute('talents:?query:', function(query) {
            versions.update(query);
            document.title = base_title + ' - Talents';
            setActiveNav("#talents");

            if (!$("#nav-talents").length) {
                loadDataIfNeeded('', function() {
                    $("#side-nav").html(navTalents(tome));
                    load_nav_data_handler = loadNavTalents;
                    $("#content").html($("#news").html());
                });
            }
        }),

        talents_category: crossroads.addRoute("talents/{category}:?query:", function(category, query) {
            routes.talents.matched.dispatch(query);
            document.title += ' - ' + toTitleCase(category);

            $("#content-container").scrollTop(0);
            loadDataIfNeeded('talents.' + category, function() {
                var this_nav = "#nav-" + category;
                showCollapsed(this_nav);

                fillNavTalents(tome, category);
                $("#content").html(listTalents(tome, category));
                scrollToId();

                // Manually initialize .collapse; if we don't, then the first
                // click on Hide All will actually expand all.
                // See https://github.com/twbs/bootstrap/issues/5859
                $(".talent-details.collapse").collapse({toggle: false});

                enableTalentTooltips();

                fillTalentAvailability(tome, category);

                versions.updateFinished();
            });
        }),

        talents_category_type: crossroads.addRoute("talents/{category}/{type}:?query:", function(category, type, query) {
            routes.talents_category.matched.dispatch(category, query);
        }),

        talents_category_type_id: crossroads.addRoute("talents/{category}/{type}/{talent_id}:?query:", function(category, type, talent_id, query) {
            // TODO: scrollToId not yet working for talent_id links, and talent_id links aren't yet published
            routes.talents_category.matched.dispatch(category, query);
        }),

        classes: crossroads.addRoute('classes:?query:', function(query) {
            versions.update(query);
            document.title += ' - Classes';
            setActiveNav("#classes");

            if (!$("#nav-classes").length) {
                loadClassesIfNeeded(function() {
                    $("#side-nav").html(navClasses(tome));
                    load_nav_data_handler = false;
                    $("#content").html($("#news").html());
                });
            }
        }),

        classes_class: crossroads.addRoute("classes/{cls}:?query:", function(cls, query) {
            versions.update(query);

            loadClassesIfNeeded(function() {
                routes.classes.matched.dispatch(query);
                document.title += ' - ' + tome[versions.current].classes.classes_by_id[cls].display_name;

                $("#content-container").scrollTop(0);

                var this_nav = "#nav-" + cls;
                showCollapsed(this_nav);

                $("#content").html(listClasses(tome, cls));
                scrollToId();

                fillClassTalents(tome, cls);

                versions.updateFinished();
            });
        }),

        classes_class_subclass: crossroads.addRoute("classes/{cls}/{subclass}:?query:", function(cls, subclass, query) {
            routes.classes_class.matched.dispatch(cls, query);
        })
    };

    function parseHash(new_hash, old_hash) {
         crossroads.parse(new_hash);
    }

    hasher.prependHash = '';
    hasher.initialized.add(parseHash);
    hasher.changed.add(parseHash);
    hasher.init();
}

function loadData(data_file, success) {
    $.ajax({
        url: "data/" + versions.current + "/" + data_file + ".json",
        dataType: "json"
    }).success(success);
    // FIXME: Error handling
}

/**Handler for expanding nav items. Takes a jQuery element that's being
 * expanded and does any on-demand loading of the data for that nav item.
 */
load_nav_data_handler = false;

/**Loads a section of JSON data into the tome object if needed, then executes
 * the success function handler.
 *
 * For example, if data_file is "talents.chronomancy", then this function
 * loads talents_chronomancy.json to tome.talents.chronomancy then calls
 * success(tome.talents.chronomancy).
 */
function loadDataIfNeeded(data_file, success) {
    var parts, last_part, tome_part;

    // Special case: No data has been loaded at all.
    // Load top-level data, then reissue the request.
    if (!tome[versions.current]) {
        loadData('tome', function(data) {
            data.hasMajorChanges = versions.asMajor(data.version) != versions.asMajor(versions.ALL[0]);
            data.hasMinorChanges = data.version != versions.ALL[0] &&
                !versions.isMajor(data.version) &&
                data.version != 'master';

            data.version = versions.name(data.version);
            data.majorVersion = versions.asMajor(data.version);

            data.fixups = {};

            tome[versions.current] = data;
            loadDataIfNeeded(data_file, success);
        });
        return;
    }

    // Special case: No data file requested.
    if (!data_file) {
        success(tome);
        return;
    }

    // General case: Walk the object tree to find where the requested file
    // should go, and load it.
    parts = data_file.split(".");
    last_part = parts.pop();
    tome_part = tome[versions.current];

    for (var i = 0; i < parts.length; i++) {
        if (typeof(tome_part[parts[i]]) === 'undefined') {
            tome_part[parts[i]] = {};
        }
        tome_part = tome_part[parts[i]];
    }

    if (!tome_part[last_part]) {
        loadData(data_file, function(data) {
            tome_part[last_part] = data;
            success(data);
        });
    } else {
        success(tome_part[last_part]);
    }
}

window.onerror = function(msg, url, line) {
    $("html").removeClass("wait");

    if ($("#content").html() === 'Loading...') {
        $("#content").html('');
    }

    $("#content").prepend(
        '<div class="alert alert-danger">' +
            'Internal error: ' + escapeHtml(msg || '') +
            ' on ' + url + ' line ' + line +
            '<button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>'  +
        '</div>'
    );
}

$(function() {
    // See http://stackoverflow.com/a/10801889/25507
    $(document).ajaxStart(function() { $("html").addClass("wait"); });
    $(document).ajaxStop(function() { $("html").removeClass("wait"); });

    $("#side-nav-container .page-header").height($("#content-header").height());

    // Clicking on a ".clickable" element triggers the <a> within it.
    $("html").on("click", ".clickable", function(e) {
        if (e.target.nodeName == 'A') {
            // If the user clicked on the link itself, then simply let
            // the browser handle it.
            return true;
        }

        $(this).find('a').click();
    });

    // Hack: Clicking the expand / collapse within an <a> doesn't trigger the <a>.
    $("#side-nav").on("click", ".dropdown", function(e) {
        e.preventDefault();
    });

    $("#side-nav").on("shown.bs.collapse", ".collapse", function(e) {
        if (load_nav_data_handler) {
            load_nav_data_handler($(this));
        }
    });

    $("html").on("error", "img", function() {
        $(this).hide();
    });

    makeStickyHeader($("#content-header"), $("#content-container"));
    enableExpandCollapseAll();
    versions.init($(".ver-dropdown"), $(".ver-dropdown-container"));
    configureImgSize();

    // Track Google Analytics as we navigate from one subpage / hash link to another.
    // Based on http://stackoverflow.com/a/4813223/25507
    // Really old browsers don't support hashchange.  A plugin is available, but I don't really care right now.
    $(window).on('hashchange', function() {
        _gaq.push(['_trackPageview', location.pathname + location.search + location.hash]);
    })

    // We explicitly do NOT use var, for now, to facilitate inspection in Firebug.
    // (Our route handlers and such currently also rely on tome being global.)
    tome = {};

    initializeRoutes();
});