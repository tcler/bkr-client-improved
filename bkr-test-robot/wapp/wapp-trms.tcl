#!/usr/bin/env tclsh
#package require wapp
lappend ::auto_path $::env(HOME)/lib /usr/local/lib /usr/lib64 /usr/lib
package require sqlite3
package require runtestlib 1.1
package require json ;# Add JSON package for parsing

namespace import ::runtestlib::*

source /usr/local/lib/wapp.tcl

# User authentication and session management
namespace eval auth {
    variable sessions [dict create]
    variable users [dict create]
    variable session_expiry 604800 ;# 7 days in seconds (7 * 24 * 60 * 60)
    variable session_dir "/etc/trms/sessions"
    variable session_file "/etc/trms/users.conf"

    # Initialize users from configuration file
    proc init_users {} {
        variable users
        variable session_file

        # Create session directory if it doesn't exist
        if {![file exists $::auth::session_dir]} {
            file mkdir $::auth::session_dir
        }

        # Load users from configuration file
        if {[file exists $session_file]} {
            set fd [open $session_file r]
            while {[gets $fd line] >= 0} {
                set line [string trim $line]
                if {$line eq "" || [string match "#*" $line]} continue
                set parts [split $line ":"]
                if {[llength $parts] >= 2} {
                    set username [string trim [lindex $parts 0]]
                    set password [string trim [lindex $parts 1]]
                    dict set users $username $password
                }
            }
            close $fd
        } else {
            # Create default configuration file with sample users
            set fd [open $session_file w]
            puts $fd "# User configuration file for TRMS"
            puts $fd "# Format: username:password"
            puts $fd "#"
            puts $fd "admin:admin123"
            puts $fd "testuser:testpass"
            close $fd
            dict set users "admin" "admin123"
            dict set users "testuser" "testpass"
        }

        # Load persistent sessions
        load_persistent_sessions
    }

    # Load persistent sessions from disk
    proc load_persistent_sessions {} {
        variable sessions
        variable session_dir

        if {![file exists $session_dir]} {
            return
        }

        set now [clock seconds]
        foreach session_file [glob -nocomplain [file join $session_dir *.session]] {
            if {[catch {
                set fd [open $session_file r]
                set session_data [read $fd]
                close $fd

                set session_dict [dict create {*}$session_data]
                set expiry [dict get $session_dict expiry]

                # Only load if not expired
                if {$now < $expiry} {
                    set session_id [file rootname [file tail $session_file]]
                    dict set sessions $session_id $session_dict
                } else {
                    # Remove expired session file
                    file delete $session_file
                }
            } error]} {
                puts "Warning: Failed to load session file $session_file: $error"
            }
        }
    }

    # Save session to disk
    proc save_session_to_disk {session_id session_data} {
        variable session_dir

        set session_file [file join $session_dir $session_id.session]
        if {[catch {
            set fd [open $session_file w]
            foreach {key value} $session_data {
                puts $fd "$key {$value}"
            }
            close $fd
        } error]} {
            puts "Error saving session $session_id: $error"
        }
    }

    # Delete session from disk
    proc delete_session_from_disk {session_id} {
        variable session_dir

        set session_file [file join $session_dir $session_id.session]
        if {[file exists $session_file]} {
            file delete $session_file
        }
    }

    # Clean up expired sessions
    proc cleanup_expired_sessions {} {
        variable sessions
        variable session_dir

        set now [clock seconds]
        set expired_sessions [list]

        # Clean memory sessions
        dict for {session_id session_data} $sessions {
            set expiry [dict get $session_data expiry]
            if {$now >= $expiry} {
                lappend expired_sessions $session_id
            }
        }

        foreach session_id $expired_sessions {
            dict unset sessions $session_id
        }

        # Clean disk sessions
        if {[file exists $session_dir]} {
            foreach session_file [glob -nocomplain [file join $session_dir *.session]] {
                if {[catch {
                    set fd [open $session_file r]
                    set session_data [read $fd]
                    close $fd

                    set session_dict [dict create {*}$session_data]
                    set expiry [dict get $session_dict expiry]

                    if {$now >= $expiry} {
                        file delete $session_file
                    }
                } error]} {
                    puts "Warning: Failed to check session file $session_file: $error"
                }
            }
        }
    }

    # Generate random session ID
    proc generate_session_id {} {
        return [string map {" " ""} [exec uuidgen]]
    }

    # Create new session with 7-day expiry
    proc create_session {username} {
        variable sessions
        variable session_expiry

        set session_id [generate_session_id]
        set expiry [expr {[clock seconds] + $session_expiry}]

        set session_data [dict create \
            username $username \
            created [clock seconds] \
            expiry $expiry \
            last_access [clock seconds]]

        dict set sessions $session_id $session_data

        # Save to disk for persistence
        save_session_to_disk $session_id $session_data

        return $session_id
    }

    # Validate session and update last access time
    proc validate_session {session_id} {
        variable sessions

        if {![dict exists $sessions $session_id]} {
            # Try to load from disk
            set session_file [file join $::auth::session_dir $session_id.session]
            if {[file exists $session_file]} {
                if {[catch {
                    set fd [open $session_file r]
                    set session_data [read $fd]
                    close $fd

                    set session_dict [dict create {*}$session_data]
                    set expiry [dict get $session_dict expiry]

                    # Check if session has expired
                    if {[clock seconds] > $expiry} {
                        file delete $session_file
                        return 0
                    }

                    dict set sessions $session_id $session_dict
                } error]} {
                    return 0
                }
            } else {
                return 0
            }
        }

        set session_data [dict get $sessions $session_id]
        set expiry [dict get $session_data expiry]

        # Check if session has expired
        if {[clock seconds] > $expiry} {
            dict unset sessions $session_id
            delete_session_from_disk $session_id
            return 0
        }

        # Update last access time and extend expiry
        dict set session_data last_access [clock seconds]
        # Reset expiry to 7 days from now on each access
        dict set session_data expiry [expr {[clock seconds] + $::auth::session_expiry}]
        dict set sessions $session_id $session_data

        # Update disk storage
        save_session_to_disk $session_id $session_data

        return 1
    }

    # Get session username
    proc get_username {session_id} {
        variable sessions
        if {[dict exists $sessions $session_id]} {
            return [dict get $sessions $session_id username]
        }
        return ""
    }

    # Delete session (logout)
    proc delete_session {session_id} {
        variable sessions
        dict unset sessions $session_id
        delete_session_from_disk $session_id
    }

    # Validate user credentials
    proc authenticate {username password} {
        variable users
        set home "/home/$username"
        if [file isdirectory $home] {
            return [expr [exec stat -c %i $home] eq $password]
        } elseif {[dict exists $users $username]} {
            return [expr {[dict get $users $username] eq $password}]
        } else {
            return 0
        }
    }

    # Get session ID from request
    proc get_session_id_from_request {cookie_header} {
        if {$cookie_header eq ""} { return "" }

        foreach cookie_pair [split $cookie_header ";"] {
            set cookie_pair [string trim $cookie_pair]
            set parts [split $cookie_pair "="]
            if {[llength $parts] == 2} {
                lassign $parts name value
                if {$name eq "session_id"} {
                    return [string trim $value]
                }
            }
        }
        return ""
    }

    # Check if user is logged in
    proc is_logged_in {cookie_header} {
        set session_id [get_session_id_from_request $cookie_header]
        if {$session_id eq ""} { return 0 }
        return [validate_session $session_id]
    }

    # Get current logged in username
    proc get_logged_user {cookie_header} {
        set session_id [get_session_id_from_request $cookie_header]
        if {$session_id eq ""} { return "" }
        return [get_username $session_id]
    }

    # Periodic cleanup of expired sessions (called occasionally)
    proc periodic_cleanup {} {
        # Run cleanup with 10% probability on each call
        if {rand() < 0.1} {
            cleanup_expired_sessions
        }
    }
}

# Initialize user data and run initial cleanup
auth::init_users
auth::cleanup_expired_sessions

# Helper procedures for session management
proc get_session_id {} {
    set cookie [wapp-param HTTP_COOKIE]
    return [auth::get_session_id_from_request $cookie]
}
proc is_logged_in {} {
    set cookie [wapp-param HTTP_COOKIE]
    auth::periodic_cleanup
    return [auth::is_logged_in $cookie]
}
proc get_logged_user {} {
    set cookie [wapp-param HTTP_COOKIE]
    return [auth::get_logged_user $cookie]
}

proc get_query_user {} {
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} {
    set quser [get_logged_user]
  }
  return $quser
}

proc common-header {logged_user} {
  wapp {
    <title>🎃▦bkr-test-robot▦🎃</title>
    <style>
    /* Login dialog styles */
    .login-dialog {
        display: none;
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        z-index: 1000;
        min-width: 300px;
    }

    .login-overlay {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0,0,0,0.5);
        z-index: 999;
    }

    .login-form {
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .login-input {
        padding: 8px;
        border: 1px solid #ddd;
        border-radius: 4px;
    }

    .logout-button, .login-button {
        background: #3498db;
        color: white;
        border: none;
        padding: 0 6px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 18px;
        font-family: cursive;
    }

    .login-button:hover {
        background: #2980b9;
    }

    .close-login {
        position: absolute;
        top: 10px;
        right: 10px;
        background: none;
        border: none;
        font-size: 18px;
        cursor: pointer;
    }

    .user-info {
        display: flex;
        align-items: center;
        gap: 10px;
        color: white;
    }

    .logout-button:hover {
        background: #c0392b;
    }

    .header {
        background-color: #2c3e50;
        padding: 0 10px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .logo a {
        font-size: 20px;
        font-weight: bold;
        text-decoration: none;
        color: white;
        font-family: monospace;
    }

    /* Navigation dropdown styles */
    .nav-container {
        display: flex;
        gap: 20px;
        align-items: center;
        flex: 1;
        margin-left: 30px;
    }

    .nav-dropdown {
        position: relative;
        display: inline-block;
    }

    .nav-button {
        background: #34495e;
        color: white;
        border: none;
        padding: 8px 16px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 16px;
        font-family: monospace;
        transition: background-color 0.3s;
    }

    .nav-button:hover {
        background: #3498db;
    }

    .dropdown-content {
        display: none;
        position: absolute;
        background-color: white;
        min-width: 200px;
        box-shadow: 0 8px 16px rgba(0,0,0,0.2);
        border-radius: 4px;
        z-index: 1001;
        top: 100%;
        left: 0;
        margin-top: 5px;
    }

    .dropdown-content a {
        color: #2c3e50;
        padding: 12px 16px;
        text-decoration: none;
        display: block;
        border-bottom: 1px solid #ecf0f1;
        transition: background-color 0.2s;
    }

    .dropdown-content a:hover {
        background-color: #ecf0f1;
    }

    .dropdown-content a:last-child {
        border-bottom: none;
    }

    .show {
        display: block;
    }

    .dropdown-header {
        background: #3498db;
        color: white;
        padding: 10px 16px;
        font-weight: bold;
        border-radius: 4px 4px 0 0;
    }
    </style>

    <!-- Login Dialog -->
    <div class="login-overlay" id="loginOverlay"></div>
    <div class="login-dialog" id="loginDialog">
        <button class="close-login" onclick="hideLogin()"> X </button>
        <h3>User Login</h3>
        <form class="login-form" id="loginForm">
            <input type="text" name="username" placeholder="Username" class="login-input" required>
            <input type="password" name="password" placeholder="Password" class="login-input" required>
            <button type="submit" class="login-button">Login</button>
        </form>
        <div id="loginMessage" style="margin-top: 10px; color: red;"></div>
    </div>

    <div class="header">
        <div class="logo"><a style="color: white;" href="/main">🎃bkr-test-robot🎃</a></div>

        <!-- Navigation dropdowns -->
        <div class="nav-container" id="navContainer">
            <!-- Navigation dropdowns will be generated by JavaScript -->
        </div>

        <div class="user-info" id="userInfo">
  }

  if {$logged_user ne ""} {
      wapp-subst {<span>Welcome, %html($logged_user)</span>}
      wapp {<button class="logout-button" onclick="logout()">Logout</button>}
  } else {
      wapp {<button class="login-button" onclick="showLogin()">Login</button>}
  }
  wapp {</div></div>
    <script>
    // Global variable to store navigation data
    let navigationData = {};

    // Load navigation data from server
    async function loadNavigationData() {
        try {
            const response = await fetch('/navigators');
            navigationData = await response.json();
            initNavigationDropdowns();
        } catch (error) {
            console.error('Failed to load navigation data:', error);
            // Fallback to empty data
            navigationData = {};
        }
    }

    // Initialize navigation dropdowns based on loaded data
    function initNavigationDropdowns() {
        const navContainer = document.getElementById('navContainer');
        navContainer.innerHTML = '';

        // Create dropdown for each category
        Object.keys(navigationData).forEach(category => {
            const links = navigationData[category];
            if (links && links.length > 0) {
                const dropdown = createDropdown(category, links);
                navContainer.appendChild(dropdown);
            }
        });

        // Re-initialize dropdown event listeners
        initDropdowns();
    }

    // Create a dropdown element
    function createDropdown(category, links) {
        const dropdownDiv = document.createElement('div');
        dropdownDiv.className = 'nav-dropdown';
        dropdownDiv.id = `${category.replace(/[^a-zA-Z0-9]/g, '')}Dropdown`;

        // Create dropdown button
        const button = document.createElement('button');
        button.className = 'nav-button';
        button.textContent = `${category}↡`;
        button.setAttribute('onmouseover', `showDropdown('${dropdownDiv.id}')`);

        // Create dropdown content
        const contentDiv = document.createElement('div');
        contentDiv.className = 'dropdown-content';
        contentDiv.id = `${dropdownDiv.id}Content`;

        // Add header
        const header = document.createElement('div');
        header.className = 'dropdown-header';
        header.textContent = category;
        contentDiv.appendChild(header);

        // Add links
        links.forEach(link => {
            const a = document.createElement('a');
            a.href = link.url;
            a.textContent = link.name;
            a.target = '_blank';
            contentDiv.appendChild(a);
        });

        dropdownDiv.appendChild(button);
        dropdownDiv.appendChild(contentDiv);

        return dropdownDiv;
    }

    // Login dialog functions
    function showLogin() {
        document.getElementById('loginOverlay').style.display = 'block';
        document.getElementById('loginDialog').style.display = 'block';
    }

    function hideLogin() {
        document.getElementById('loginOverlay').style.display = 'none';
        document.getElementById('loginDialog').style.display = 'none';
        document.getElementById('loginMessage').textContent = '';
        // Clear form fields
        document.querySelector('input[name="username"]').value = '';
        document.querySelector('input[name="password"]').value = '';
    }

    // Dropdown management
    let dropdownTimers = {};

    function showDropdown(dropdownId) {
        const content = document.getElementById(dropdownId + 'Content');
        if (content) {
            content.classList.add('show');
            // Clear any existing timer for this dropdown
            if (dropdownTimers[dropdownId]) {
                clearTimeout(dropdownTimers[dropdownId]);
            }
        }
    }

    function hideDropdown(dropdownId) {
        const content = document.getElementById(dropdownId + 'Content');
        if (content) {
            content.classList.remove('show');
        }
    }

    function scheduleHideDropdown(dropdownId) {
        // Clear existing timer
        if (dropdownTimers[dropdownId]) {
            clearTimeout(dropdownTimers[dropdownId]);
        }
        // Set new timer to hide after 2 seconds
        dropdownTimers[dropdownId] = setTimeout(() => {
            hideDropdown(dropdownId);
        }, 1200);
    }

    // Initialize dropdown event listeners
    function initDropdowns() {
        const navContainer = document.getElementById('navContainer');
        const dropdowns = navContainer.querySelectorAll('.nav-dropdown');

        dropdowns.forEach(dropdown => {
            const dropdownId = dropdown.id;
            const content = document.getElementById(dropdownId + 'Content');

            if (dropdown && content) {
                // Show on mouse enter
                dropdown.addEventListener('mouseenter', () => {
                    showDropdown(dropdownId);
                });

                // Hide on mouse leave with delay
                dropdown.addEventListener('mouseleave', () => {
                    scheduleHideDropdown(dropdownId);
                });

                // Keep open when mouse is over content
                content.addEventListener('mouseenter', () => {
                    showDropdown(dropdownId);
                });

                // Hide when mouse leaves content
                content.addEventListener('mouseleave', () => {
                    scheduleHideDropdown(dropdownId);
                });
            }
        });
    }

    // Handle login form submission
    function handleLoginSubmit(e) {
        e.preventDefault();

        const username = document.querySelector('input[name="username"]').value;
        const password = document.querySelector('input[name="password"]').value;

        // Create JSON payload instead of form data
        const loginData = {
            username: username,
            password: password
        };

        fetch('/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(loginData)
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Login successful - update UI without page reload
                hideLogin();
                updateUserInterface(username);
            } else {
                // Show error message
                document.getElementById('loginMessage').textContent = data.message || 'Login failed';
            }
        })
        .catch(error => {
            document.getElementById('loginMessage').textContent = 'Login request failed: ' + error.message;
        });
    }

    // Handle logout
    function logout() {
        fetch('/logout', {
            method: 'POST'
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Logout successful - update UI without page reload
                updateUserInterface(null);
            } else {
                alert('Logout failed: ' + (data.message || 'Unknown error'));
            }
        })
        .catch(error => {
            alert('Logout request failed: ' + error.message);
        });
    }

    // Update UI based on login status - without changing URL
    function updateUserInterface(username) {
        const userInfoDiv = document.getElementById('userInfo');
        if (userInfoDiv) {
            if (username) {
                // User is logged in
                userInfoDiv.innerHTML = `
                    <span>Welcome, ${escapeHtml(username)}</span>
                    <button class="logout-button" onclick="logout()">Logout</button>
                `;
            } else {
                // User is logged out
                userInfoDiv.innerHTML = `<button class="login-button" onclick="showLogin()">Login</button>`;
            }
        }
    }

    // Helper function to escape HTML
    function escapeHtml(unsafe) {
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // Check authentication status on page load
    function checkAuthStatus() {
        fetch('/check-auth')
            .then(response => response.json())
            .then(data => {
                if (data.logged_in) {
                    updateUserInterface(data.username);
                } else {
                    updateUserInterface(null);
                }
            })
            .catch(error => {
                console.log('Auth check failed:', error);
            });
    }

    // Close login dialog when clicking overlay
    document.getElementById('loginOverlay').addEventListener('click', hideLogin);

    // Attach event listener after DOM is loaded
    document.addEventListener('DOMContentLoaded', function() {
        const loginForm = document.getElementById('loginForm');
        if (loginForm) {
            loginForm.addEventListener('submit', handleLoginSubmit);
        }

        // Load navigation data and initialize dropdowns
        loadNavigationData();

        // Check authentication status when page loads
        checkAuthStatus();
    });
    </script>
  }
}

# Navigation data endpoint
proc wapp-page-navigators {} {
    wapp-allow-xorigin-params
    wapp-mimetype application/json

    set nav_file "/etc/trms/navigators.json"

    if {[file exists $nav_file]} {
        # Read from existing JSON file
        if {[catch {
            set fd [open $nav_file r]
            set json_data [read $fd]
            close $fd
            wapp $json_data
        } error]} {
            wapp-reply-code "500 Internal Server Error"
            wapp-subst {{"error": "Error reading navigation file: %html($error)"}}
        }
    } else {
        # Return demo JSON data
        wapp {
{
  "WorkResource": [
    { "name": "Beaker System", "url": "https://beaker.engineering.redhat.com" },
    { "name": "Linux Weekly News", "url": "https://lwn.net" }
  ],
  "Entertainment": [
    { "name": "Bilibili", "url": "https://www.bilibili.com" },
    { "name": "YouTube", "url": "https://www.youtube.com" },
    { "name": "Reddit", "url": "https://www.reddit.com" }
  ],
  "Others/MISC": [
    { "name": "wikipedia", "url": "https://www.wikipedia.org/" }
  ]
}
        }
    }
}

proc common-footer {{quser ""}} {
  if {$quser == ""} { set quser [get_query_user] }
  wapp {<footer>}
  if {$quser == {}} {
    wapp {<br>}
  } else {
    wapp-subst {
    <div id="hostUsage" style="
      background: #f0f8ff;
      font-family: monospace;
      text-align: center;">
    </div>

    <script>
    function updateHostUsage() {
        const username = "%unsafe($quser)";
        const url = `${window.location.origin}/host-usage?user=${username}`;

        fetch(url)
            .then(response => response.json())
            .then(data => {
                const hostUsage = data.hostusage || 'N/A';
                const servAddr = data.servaddr || 'N/A';
                const clntIp = data.clntip || 'N/A';
                const displayText = `{RecipeUse(${hostUsage}) - clnt(${clntIp}) serv(${servAddr})}`;
                document.getElementById('hostUsage').textContent = displayText;
            })
            .catch(error => {
                document.getElementById('hostUsage').textContent = 
                    'get host-usage fail:' + error.message;
            });
    }

    updateHostUsage();

    //update every 5m
    setInterval(updateHostUsage, 5 * 60 * 1000);
    </script>
    }
  }
  wapp-trim {
      <div style="text-align: center;">
        <strong>
          Powered by <a href="https://github.com/tcler/bkr-client-improved">bkr-client-improved</a> and
          <a href="https://wapp.tcl-lang.org">wapp</a>
        </strong>
        |
        <a href="mailto:yin-jianhong@163.com">@JianhongYin</a>
        <a href="mailto:nzjachen@gmail.com">@ZhenjieChen</a>
      </div>
      </footer>
      </html>
  }
}

# Login page handler
proc wapp-page-login {} {
    wapp-allow-xorigin-params
    wapp-mimetype application/json

    if {[wapp-param REQUEST_METHOD] ne "POST"} {
        wapp {{"success": false, "message": "Invalid request method"}}
        return
    }

    # Get JSON data from request body
    set post_data [wapp-param CONTENT]
    if {$post_data eq ""} {
        wapp {{"success": false, "message": "No data received"}}
        return
    }

    # Parse JSON data
    if {[catch {set login_dict [json::json2dict $post_data]} error]} {
        wapp {{"success": false, "message": "Invalid JSON data"}}
        return
    }

    # Extract username and password from JSON
    set username [dict get $login_dict username]
    set password [dict get $login_dict password]

    if {$username eq "" || $password eq ""} {
        wapp {{"success": false, "message": "Username and password cannot be empty"}}
        return
    }

    if {[auth::authenticate $username $password]} {
        set session_id [auth::create_session $username]

        # Set Cookie - fixed wapp-set-cookie usage (only key and value)
        wapp-set-cookie session_id $session_id

        wapp {{"success": true, "message": "Login successful"}}
    } else {
        wapp {{"success": false, "message": "Invalid username or password"}}
    }
}

# Logout page handler
proc wapp-page-logout {} {
    wapp-allow-xorigin-params
    wapp-mimetype application/json

    set session_id [get_session_id]
    if {$session_id ne ""} {
        auth::delete_session $session_id
    }

    # Clear Cookie - fixed wapp-set-cookie usage
    wapp-set-cookie session_id ""

    wapp {{"success": true, "message": "Logout successful"}}
}

# Check authentication status page (for AJAX checks)
proc wapp-page-check-auth {} {
    wapp-allow-xorigin-params
    wapp-mimetype application/json

    set cookie [wapp-param HTTP_COOKIE]
    if [auth::is_logged_in $cookie] {
        set username [auth::get_logged_user $cookie]
        wapp-subst {{"logged_in": true, "username": "%html($username)"}}
    } else {
        wapp {{"logged_in": false}}
    }
}

proc wapp-default {} {
  wapp-allow-xorigin-params
  wapp-content-security-policy {
    default-src 'self';
    style-src 'self' 'unsafe-inline';
    script-src 'self' 'unsafe-inline';
  }

  set logged_user [get_logged_user]
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} { set quser $logged_user }

  if {$quser == {}} {
    wapp-redirect main
  } elseif {![file exists /home/${quser}/.testrundb/testrun.db]} {
    wapp-redirect [wapp-param BASE_URL]/main?user=${quser}&notexist=1
  }

  wapp {<!-- vim: set sw=4 ts=4 et: -->
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
  }

  common-header $logged_user

  wapp-trim {
    <style>
        /* Copy button styles */
        .copy-btn {
            display: none;
            position: absolute;
            background: #f5f5f5;
            color: white;
            border: none;
            border-radius: 3px;
            padding: 2px 6px;
            font-size: 16px;
            cursor: pointer;
            z-index: 1000;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: all 0.2s ease;
        }

        .copy-btn:hover {
            background: #2980b9;
            transform: scale(1.05);
        }

        .copy-btn:active {
            transform: scale(0.95);
        }

        .copy-btn.success {
            background: #27ae60;
        }

        .copy-btn.error {
            background: #e74c3c;
        }

        /* Header cell and first column hover effects */
        .header-cell:hover .copy-btn,
        .first-column:hover .copy-btn {
            display: inline-block;
        }

        /* Ensure cells have relative positioning for absolute positioned buttons */
        .header-cell, .first-column {
            position: relative;
        }

        div.controlPanelCall {
            position: fixed;
            z-index: 99;
            top: 144pt;
            left: 0pt;
            background-color: #454;
            background-color: #CD7F32;
            opacity: 0.8;
            border: solid 3px;
            border-color: #D9D919;
            border-color: #cd7f32;
        }
        div.controlPanel {
            position: fixed;
            z-index: -1;
            display: none;
            top: 144pt;
            left: 0pt;
            background-color: #454;
            background-color: #CD7F32;
            opacity: 0.96;
            border: solid 3px;
            border-color: #D9D919;
            border-color: #cd7f32;
        }

        .container {
            padding: 5px;
            width: 99%;
            margin: 0 auto;
            height: calc(94vh - 70px); /* Subtract header height */
            display: flex;
            flex-direction: column;
        }

        .controls {
            background-color: white;
            padding: 0px;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 5px;
        }

        .fieldset {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            width: 100%;
            border-style: none;
            border-left-width: 1px;
            padding: 0 2px;
        }

        .query-form {
            display: flex;
            gap: 2px;
	    width: 100%;
        }

        .radio-group {
            display: flex;
            align-items: center;
            gap: 1px;
            flex: 1;
            margin-bottom: 1px;
            border-right-width: 15px;
            padding-right: 10px;
        }
        #queryButton {
            margin: 0px 10px;
            cursor: pointer;
        }

        .radio-item {
            display: inline; /* Ensure controls are centered, inline-flex would cause top alignment */
            gap: 5px;
        }

        .search-input {
            padding: 0px 0px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 16px;
            width: 200px;
            transition: border-color 0.3s;
            margin-left: auto; /* push to right side */
        }

        .search-input:focus {
            outline: none;
            border-color: #3498db;
            box-shadow: 0 0 5px rgba(52, 152, 219, 0.3);
        }

        .pkg-select {
            display: none;
            z-index: -1;
            flex-basis: 100%;
            order: 1;
        }

        .pkg-select.show {
            width: 100%;
            z-index: 110;
            display: block;
        }

        .table-container {
            overflow: auto;
            flex: 1; /* Take up remaining space */
            width: 100%;
            border: 1px solid #ddd;
            border-radius: 0px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            position: relative;
        }

        .detail-div {
            position: absolute;
            top: 88px;
            left: 10px;
            width: 96%;
            flex: 1; /* Take up remaining space */
            background-color: #f3e5ab; /* Warm beige color */
            color: #2c2c2c;
            padding: 10px;
            border: 2px solid #ff6b6b;
            max-height: 80vh; /* Limit maximum height */
            min-height: 60vh; /* Limit maximum height */
            overflow: auto; /* Enable scrolling */
        }

        .detail-header {
            position: sticky;
            top: 0;
            left: 0;
            background-color: #f3e5ab;
            z-index: 550;
            border-bottom: 1px solid #ddd;
        }
        .close-section {
            position: fixed;
            z-index: 600;
            display: flex;
            align-items: left;
            background-color: #f3e5ab;
            position: absolute;
            top: 0;
            left: 0;
        }
        .detail-close-btn {
            background-color: #ff6b6b;
            color: white;
            width: 25px;
            height: 25px;
            font-weight: bold;
            cursor: pointer;
            top: 0;
        }
        .detail-close-btn:hover {
            background-color: #ff4757;
        }
        .close-prompt {
            font-family: monospace;
            font-weight: bold;
            color: #333;
        }

        table {
            border-collapse: collapse;
            width: 99%;
            min-width: 800px;
        }

        th, td {
            border: 1px solid #ddd;
            padding: 10px;
            text-align: left;
            white-space: nowrap;
        }

        th {
            background-color: #3498db;
            color: white;
            position: sticky;
            top: 0;
            z-index: 20; /* Increase z-index to ensure header is on top */
            box-shadow: 0 2px 2px -1px rgba(0, 0, 0, 0.4); /* Add shadow for better layering */
        }
        .header-cell {
            position: sticky;
            top: 0;
            z-index: 20;
        }

        .first-column {
            font-family: monospace;
            position: sticky;
            left: 0;
            z-index: 5;
            background-color: #ecf0f1;
        }

        .first-head-column {
            position: sticky;
            left: 0;
            z-index: 30; /* Ensure first column header is on top */
            font-size: 20px;
            font-weight: bold;
            background-color: #fcf0f1;
            color: gray;
            box-shadow: 2px 0 2px -1px rgba(0, 0, 0, 0.4); /* Add shadow for better layering */
        }

        .tooltip {
            position: absolute;
            background-color: #333;
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 14px;
            z-index: 1000;
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.3s;
            max-width: 400px;
            word-wrap: break-word;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }

        .tooltip.show {
            opacity: 1;
        }

        .truncate {
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 64px;
        }

        .header-cell:hover {
            opacity: 1;
        }

        .scroll-header {
            position: sticky;
            top: 0;
            z-index: 20;
        }

        .scroll-first-column {
            position: sticky;
            left: 0;
            z-index: 5;
        }

        /* Add loading message styles */
        .loading-message {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 18px;
            color: #666;
            text-align: center;
            z-index: 10;
        }

        .loading-spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 2s linear infinite;
            margin: 0 auto 10px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
  }

  wapp {
    <div class="container">
        <div class="controlPanelCall" onmouseover="controlPanelSwitch(1);">
            V<br>V<br>V
        </div>
        <div class="controlPanel" id="cpanel" onmouseover="controlPanelSwitch(1);" onmouseout="controlPanelSwitch(0);">
            <span style="font-weight:bold; color: #bfb;"> TRMS Control Pannel </span>
            <br/>
            <input type="button" value="Delete" onclick="delList();"/>
            <input type="button" value="[Re]Run" onclick="reSubmitList();"/>
            <input type="button" value="Clone" onclick="cloneToNewRun();"/>
            <br>
            <input type="button" value="Delete Test Cases" onclick="delTestCase();"/>
        </div>

        <div class="controls">
            <form class="query-form" id="queryForm">
            <fieldset class="fieldset" id="queryFieldset">
                <input type="hidden" name="user" id="userInput" value="">
                <div class="radio-group" id="pkgRadioGroup">
                    <!-- Radio buttons will be generated here -->
                    <input type="submit" value="Query/Refresh" id="queryButton">
                </div>
                <input type="text" id="searchFilter" placeholder="Filter tests..." class="search-input">
            </fieldset>
            </form>
        </div>

        <div class="table-container">
            <!-- Add loading message -->
            <div class="loading-message" id="loadingMessage">
                <div class="loading-spinner"></div>
                <div>loading data test result ...</div>
            </div>
            <table id="resultsTable">
                <thead id="tableHeader">
                    <!-- Table header will be generated here -->
                </thead>
                <tbody id="tableBody">
                    <!-- Table body will be generated here -->
                </tbody>
            </table>
        </div>
    </div>

    <script>
        // Global variables
        let testruninfo = {
            "components": ["nfs", "cifs"],
            "test-run": {
                "nfs": [
                    "rhel8.10 NFS run for performance testing",
                    "rhel9.8 NFS run for compatibility testing",
                    "rhel10.2 NFS run for security testing"
                ],
                "cifs": [
                    "rhel-8.10 CIFS run for file sharing",
                    "rhel-9.8 CIFS run for authentication",
                    "rhel-10.2 CIFS run for encryption",
                    "rhel-9.7.z CIFS run for network stability x86_64 hahaha, abcd, efg, hijk, xyz"
                ]
            },
            "qresults": {
                "qruns": [
                    "Test Run 1 - 2023-06-01 fake data for demo tests",
                    "Test Run 2 - 2023-06-05",
                    "Test Run 3 - 2023-06-10",
                    "Test Run 4 - 2023-06-15",
                    "Test Run 5 - 2023-06-20",
                ],
                "results": []
            }
        };

        let qresults = testruninfo.qresults;
        let sortedResults = qresults.results;

        // Copy text to clipboard function
        function copyToClipboard(text, button) {
            // Save original text and style
            const originalText = button.innerHTML;
            const originalClass = button.className;

            // Use modern Clipboard API
            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(text).then(() => {
                    // Success feedback
                    button.innerHTML = '✓';
                    button.className = 'copy-btn success';
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.className = originalClass;
                    }, 2000);
                }).catch(err => {
                    // Error feedback
                    console.error('Failed to copy: ', err);
                    button.innerHTML = '✗';
                    button.className = 'copy-btn error';
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.className = originalClass;
                    }, 2000);
                });
            } else {
                // Fallback: use textarea method
                const textArea = document.createElement("textarea");
                textArea.value = text;
                textArea.style.position = "fixed";
                textArea.style.left = "-999999px";
                textArea.style.top = "-999999px";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                try {
                    document.execCommand('copy');
                    // Success feedback
                    button.innerHTML = '✓';
                    button.className = 'copy-btn success';
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.className = originalClass;
                    }, 2000);
                } catch (err) {
                    // Error feedback
                    console.error('Fallback: Failed to copy: ', err);
                    button.innerHTML = '✗';
                    button.className = 'copy-btn error';
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.className = originalClass;
                    }, 2000);
                }
                document.body.removeChild(textArea);
            }
        }

        // Create copy button
        function createCopyButton(element, textToCopy) {
            const copyBtn = document.createElement('button');
            copyBtn.className = 'copy-btn';
            copyBtn.innerHTML = '📋⧉';
            copyBtn.title = 'Copy full text';

            // Position button in top-right corner of element
            copyBtn.style.top = '2px';
            copyBtn.style.right = '2px';

            copyBtn.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent event bubbling
                copyToClipboard(textToCopy, copyBtn);
            });

            element.appendChild(copyBtn);
            return copyBtn;
        }

        const getParam = (name) => new URLSearchParams(window.location.search).get(name);
        function car(sequence) {
            if (Array.isArray(sequence)) return sequence[0];
            if (typeof sequence === 'string') return sequence.split(' ')[0];
            return undefined;
        }

        function cdr(sequence) {
            if (Array.isArray(sequence)) return sequence.slice(1);
            if (typeof sequence === 'string') return sequence.split(' ').slice(1).join(' ');
            return undefined;
        }

        function selectCol(id) {
            var col = document.getElementsByClassName("checkCol")[id];
            var chkRuns = document.querySelectorAll("input.selectTestRun");

            for (var i=0; i < chkRuns.length; i++) {
                var testid = chkRuns[i].id.split(" ");
                if (testid[1] != col.id) {
                    continue;
                }
                var row = chkRuns[i].closest('tr');
                if (row && row.style.display === 'none') {
                    continue;
                }

                if (col.checked == true) {
                    //chkRuns[i].style.visibility="visible";
                    chkRuns[i].checked=true;
                } else {
                    //chkRuns[i].style.visibility="hidden";
                    chkRuns[i].checked=false;
                }
            }
        }

        function showDetail(id) {
            const divid = `div${id}`;
            const div = document.getElementById(divid);
            div.style.zIndex = "500";
            div.style.display = "block";
        }

        function hideDetail(id) {
            const div = document.getElementById(id);
            div.style.zIndex = "-1";
            div.style.display = "none";
        }

	var cpanelTO;
	function controlPanelSwitch(on) {
		var obj = document.getElementById('cpanel')
		if (on == 1) {
			obj.style.zIndex = "100";
			obj.style.display = "block";
			clearTimeout(cpanelTO);
		} else {
			cpanelTO = setTimeout(function() {
				obj.style.zIndex = "-1";
				obj.style.display = "none";
			}, 2000)
		}
	}

	function post(path, params, method) {
		method = method || "post"; // Set method to post by default if not specified.

		// The rest of this code assumes you are not using a library.
		// It can be made less wordy if you use one.
		var form = document.createElement("form");
		form.setAttribute("method", method);
		form.setAttribute("action", path);
		form.setAttribute("id", "UpdateDB");

		for(var key in params) {
			if(params.hasOwnProperty(key)) {
				var hiddenField = document.createElement("input");
				hiddenField.setAttribute("type", "hidden");
				hiddenField.setAttribute("name", key);
				hiddenField.setAttribute("value", params[key]);

				form.appendChild(hiddenField);
			}
		}

		document.body.appendChild(form);
		form.submit();
		document.body.removeChild(form);
	}

	function delList() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "deltest";

		var testlist = ""
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += `${testid} ${qresults.qruns[j]}&`;
			}
		}
		var r = confirm("Are you sure delete these test?\n"+testlist);
		if (r != true) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

	function reSubmitList() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "resubmit-list";

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				j = testobj[1];
				testlist += `${testid} ${qresults.qruns[j]}\n`;
			}
		}
		var r = confirm(`Are you sure resubmit these test?\n${testlist}`);
		if (r != true) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

	function cloneToNewRun() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "clone";

		var testlist = "";
		var chkItem = document.querySelectorAll("input.selectTestRun, input.selectTestNil");
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testobj = chkItem[i].id.split(" ");
				testid = testobj[0];
				testlist += testid + ';';
			}
		}
		var name = prompt("============> Input the distro and params, e.g <============\nRHEL-7.2  kernel-3.10.0-282.el7 -dbgk -cc=k@r.com\nRHEL-7.6 -alone -random -kdump=  info:kernel,nfs-utils", "");
		if (!name) {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist, distro: name});
	}

	function delTestCase() {
		const nurl = new URL(window.location.href);
		nurl.pathname = "delTestCase";

		var testlist = ""
		var chkItem = document.getElementsByClassName('selectTestCase');
		for (var i=0; i<chkItem.length; i++) {
			if (chkItem[i].checked == true) {
				var testid = chkItem[i].id;
				testlist += testid + ';';
			}
		}
		if (testlist == "") {
			return 0;
		}
		var r = confirm("Are you sure delete these test cases?\n"+testlist);
		if (r != true || testlist == "") {
			return 0;
		}
		post(nurl.toString(), {testlist: testlist});
	}

        // Initialize interface
        function initializeInterface() {
            // Create component/package radio controls
            createRadioButtons();

            // Render table
            sortedResults = sortTestResults(qresults.results);
            renderTable();

            createResultDetailDivs();
            setupSearchFilter();
        }

        // Create radio buttons
        function createRadioButtons() {
            const queryField = document.getElementById('queryFieldset');
            const radioGroup = document.getElementById('pkgRadioGroup');
            const userInput = document.getElementById('userInput');
            if (userInput) {
                // Get user value from URL parameters, not dependent on login status
                userInput.value = getParam('user') || '';
            }

	    radioGroup.className = 'radio-group';

            const radioItems = radioGroup.querySelectorAll('.radio-item');
            radioItems.forEach(item => item.remove());

            const allSelects = queryField.querySelectorAll('.pkg-select');
            allSelects.forEach(select => { select.remove(); });

            testruninfo.components.forEach(pkg => {
                if (!(pkg in testruninfo['test-run'])) { return; }
                const radioItem = document.createElement('div');
                radioItem.className = 'radio-item';

                const radio = document.createElement('input');
                radio.type = 'radio';
                radio.id = `pkg-${pkg}`;
                radio.name = 'pkg';
                radio.value = pkg;
                if (getParam('pkg') == pkg) {
                    radio.checked = 'checked';
                }
                radio.onclick = function() { pkgSelectSwitch(pkg); };

                const label = document.createElement('label');
                label.htmlFor = `pkg-${pkg}`;
                label.textContent = pkg;

                radioItem.appendChild(radio);
                radioItem.appendChild(label);
                radioGroup.prepend(radioItem);

                // Create select control
                const select = document.createElement('select');
                select.id = `run-${pkg}`;
                select.name = `run-${pkg}`;
                select.multiple = true;
                select.size = 5;
                select.className = 'pkg-select';

                // Add options
                testruninfo['test-run'][pkg].forEach(testrun => {
                    const option = document.createElement('option');
                    option.value = testrun;
                    option.textContent = testrun;
                    select.appendChild(option);
                });

                queryField.appendChild(select);
            });
        }

        // hide all .pkg-select
        function hideAllPkgSelects() {
            const selects = document.querySelectorAll('.pkg-select');
            selects.forEach(select => {
                select.classList.remove('show');
            });
        }

        // Radio switch to show corresponding select
        function pkgSelectSwitch(pkg) {
            const selects = document.querySelectorAll('.pkg-select');
            selects.forEach(select => {
                if (select.id === `run-${pkg}`) {
                    select.classList.toggle('show');
                } else {
                    select.classList.remove('show');
                }
            });
        }

        // Truncate string to max length with ellipsis
        function truncateString(str, maxLength = 36) {
            if (str.length <= maxLength) {
                return str;
            }
            return str.substring(0, maxLength - 3) + '...';
        }

        keepLastTwo = (path) => path.replace(/^\/+|\/+$/g, '').split('/').slice(-2).join('/');

        // Create tooltip element
        function createTooltip() {
            const tooltip = document.createElement('div');
            tooltip.className = 'tooltip';
            document.body.appendChild(tooltip);
            return tooltip;
        }

        function calculateWeight(resObj) {
            const WEIGHTS = { 'Panic': 5, 'Fail': 4, 'Warn': 3, 'Pass': 2, '': 1, null: 1 };

            return Math.max(...Object.keys(resObj)
                .filter(key => /^res\d+$/.test(key))
                .map(key => {
                    const value = resObj[key];
                    if (value === null) { return 0; }
                    const foundKey = Object.keys(WEIGHTS).find(keyword => value.includes(keyword));
                    return foundKey ? WEIGHTS[foundKey] : 6;
                }), 0);
        }
        function sortTestResults(testResults, order = 'desc') {
            // Precompute weights for better performance
            const resultsWithWeights = testResults.map(obj => ({
                data: obj,
                weight: calculateWeight(obj)
            }));

            if (order === 'desc') {
                // Descending order: higher weights first
                return resultsWithWeights.sort((a, b) => b.weight - a.weight).map(item => item.data);
            } else {
                // Ascending order: lower weights first
                return resultsWithWeights.sort((a, b) => a.weight - b.weight).map(item => item.data);
            }
        }

        // 搜索过滤功能
        function setupSearchFilter() {
            const searchInput = document.getElementById('searchFilter');
            if (!searchInput) return;

            searchInput.addEventListener('input', function(e) {
                const searchText = e.target.value.toLowerCase().trim();
                filterTableRows(searchText);
            });

            // 添加清除搜索的快捷键
            searchInput.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    e.target.value = '';
                    filterTableRows('');
                    e.target.blur();
                }
            });
        }

        function filterTableRows(searchText) {
            const tableBody = document.getElementById('tableBody');
            if (!tableBody) return;

            const rows = tableBody.querySelectorAll('tr');

            if (!searchText) {
                rows.forEach(row => {
                    row.style.display = '';
                });
                return;
            }

            rows.forEach(row => {
                let rowText = '';

                // merge text in row
                const cells = row.querySelectorAll('td');
                cells.forEach(cell => {
                    rowText += cell.textContent.toLowerCase() + ' ';
                });

                const isVisible = rowText.includes(searchText);
                row.style.display = isVisible ? '' : 'none';
            });
        }

        // Render table
        function renderTable() {
            // Render table header
            const tableHeader = document.getElementById('tableHeader');
            tableHeader.innerHTML = '';

            const headerRow = document.createElement('tr');
            const emptyHeader = document.createElement('th');
            emptyHeader.className = 'first-head-column';
            emptyHeader.textContent = ' Test  \\  TestRun ';
            headerRow.appendChild(emptyHeader);

            const maxHeader = 40;
            const tooltip = createTooltip();
            qresults.qruns.forEach((run, index) => {
                const th = document.createElement('th');
                th.className = 'header-cell';
                th.textContent = run;
                th.title = run; // Default browser tooltip
                // If length exceeds maxHeader, truncate and add tooltip
                if (run.length > maxHeader) {
                    th.textContent = truncateString(run, maxHeader);
                }

                // Create copy button - copies full content
                createCopyButton(th, run);

                //add selectCol checkbox to thead <th>
                const colChkbox = document.createElement('input');
                colChkbox.type = "checkbox";
                colChkbox.className = "checkCol";
                colChkbox.id = index;
                colChkbox.onclick = function() { selectCol(index); };
                th.prepend(colChkbox);

                headerRow.appendChild(th);
            });

            tableHeader.appendChild(headerRow);

            // Render table body
            const tableBody = document.getElementById('tableBody');
            const maxTestcase = 40;
            tableBody.innerHTML = '';

            sortedResults.forEach((resObj, rowIdx) => {
                const row = document.createElement('tr');

                // First column - test case
                const testId = resObj.testid;
                const testName = keepLastTwo(resObj.test);
                const fullTestName = resObj.test; // Full test name
                row.id = testId;
                row.ondblclick = function() { showDetail(testId); };

                const testCell = document.createElement('td');
                testCell.title = fullTestName; // Browser default tooltip shows full content
                testCell.textContent = `${rowIdx}. ${testName}`;
                testCell.className = 'first-column';
                testCell.style.paddingLeft = '0';

                // If length exceeds maxTestCase, truncate and add tooltip
                if (testName.length > maxTestcase) {
                    testCell.textContent = truncateString(testCell.textContent, maxTestcase);
                }

                // Create copy button - copies full test path
                createCopyButton(testCell, fullTestName);

                //add selectTest checkbox to test <td>
                const testChkbox = document.createElement('input');
                testChkbox.type = "checkbox";
                testChkbox.className = "selectTestCase";
                testChkbox.id = testId;
                testCell.prepend(testChkbox);
                row.appendChild(testCell);

                // Other columns - test results
                var nrun = qresults.qruns.length;
                for (let k = 0; k < nrun; k++) {
                    var res = resObj['res'+k];
                    const cell = document.createElement('td');
                    cell.id = `${testId} ${k}`;

                    var runChkbox = document.createElement('input');
                    runChkbox.type = 'checkbox';
                    runChkbox.id = `${testId} ${k}`;
                    if (!res) { res = ''; } else { res = res.trim(); }
                    runChkbox.className = 'selectTestRun';
                    if (res == '') {
                        runChkbox.className = 'selectTestNil';
                    }
                    cell.appendChild(runChkbox);

                    if (['-', 'o', ''].includes(res)) {
                        const resSpan = document.createElement('span');
                        resSpan.textContent = res;
                        cell.appendChild(resSpan);
                    } else {
                        const resarr = res.split(" ");
                        const nrecipe = resarr.length/2;
                        for (var i = 0; i < nrecipe; i++) {
                            const recipeStat = resarr[i];
                            const recipeId = resarr[i+nrecipe]
                            const statSpan = document.createElement('span');
                            const linkA = document.createElement('a');
                            if (recipeStat === "Pass") {
                                linkA.style.color = "Blue";
                            } else if (recipeStat === "Fail") {
                                linkA.style.color = "Red";
                            } else if (recipeStat === "Warn") {
                                linkA.style.color = "LimeGreen";
                            } else if (recipeStat === "Panic") {
                                linkA.style.color = "Navy";
                            } else {
                                linkA.style.color = "Gray";
                            }
                            linkA.style.fontWeight = "Bold";
                            linkA.href = `https://beaker.engineering.redhat.com/recipes/${recipeId}`;
                            linkA.textContent = recipeStat + " ";
                            statSpan.appendChild(linkA);
                            cell.appendChild(statSpan);
                        }
                    }
                    row.appendChild(cell);
                }

                tableBody.appendChild(row);
            });

            setTimeout(() => {
                setupSearchFilter();
                const searchInput = document.getElementById('searchFilter');
                filterTableRows(searchInput.value);
            }, 0);
        }

        function formatResdContent(content) {
            if (!content) return '';

            let formatted = content.replace(/\n/g, '<br>');
            formatted = formatted.replace(/  /g, ' &nbsp;&nbsp;');
            formatted = formatted.replace(/(New:)/g, '<span style="color: gray; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(Pass-?:)/g, '<span style="color: blue; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(Fail:)/g, '<span style="color: red; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(Warn:)/g, '<span style="color: orange; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(Panic:)/g, '<span style="color: navy; font-weight: bold;">$1</span>');

            formatted = formatted.replace(/(Fail<br>)/g, '<span style="color: red; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(Warn<br>)/g, '<span style="color: orange; font-weight: bold;">$1</span>');
            formatted = formatted.replace(/(RESULT[^<]*<br>)/g, '<span style="font-weight: bold;">$1</span>');
            return formatted;
        }

        function createResultDetailDivs() {
            const allDetails = document.body.querySelectorAll('.detail-div');
            if (allDetails) {
                allDetails.forEach(detail => { detail.remove(); });
            }
            const nheaderRow = document.createElement('tr');
            const maxHeader = 40;
            qresults.qruns.forEach((run, index) => {
                const td = document.createElement('td');
                td.textContent = truncateString(run, maxHeader);
                td.title = run;
                nheaderRow.appendChild(td);
            });
            sortedResults.forEach((resObj, rowIdx) => {
                const resdDiv = document.createElement('div');
                resdDiv.className = 'detail-div';
                resdDiv.id = `div${resObj.testid}`;

                // create header container
                const headerDiv = document.createElement('div');
                headerDiv.className = 'detail-header';

                // create close section container
                const closeSection = document.createElement('div');
                closeSection.className = 'close-section';

                // create close button
                const resdXBtn = document.createElement('button');
                resdXBtn.className = 'detail-close-btn';
                resdXBtn.textContent = 'X';
                resdXBtn.addEventListener('click', function(e) {
                    hideDetail(resdDiv.id);
                });

                // create close prompt text
                const closePrompt = document.createElement('span');
                closePrompt.textContent = ' - [Close me]';
                closePrompt.className = 'close-prompt';

                // add close-btn and close-prompt to close-section
                closeSection.appendChild(resdXBtn);
                closeSection.appendChild(closePrompt);

                // append close-section to header container
                headerDiv.appendChild(closeSection);

                // append header to top div
                resdDiv.appendChild(headerDiv);

                const br = document.createElement('br');
                const p = document.createElement('p');
                p.textContent = resObj.test;
                resdDiv.appendChild(br);
                resdDiv.appendChild(p);

                const resdTable = document.createElement('table');
                resdTable.appendChild(nheaderRow.cloneNode(true));

                const resdRow = document.createElement('tr');
                var nrun = qresults.qruns.length;
                for (let k = 0; k < nrun; k++) {
                    const cell = document.createElement('td');
                    var resd = resObj['resd'+k];
                    if (!resd) { resd = ''; }
                    cell.innerHTML = formatResdContent(resd);
                    resdRow.appendChild(cell);
                }
                resdTable.appendChild(resdRow);
                resdDiv.appendChild(resdTable);
                resdDiv.style.zIndex = "-1";
                resdDiv.style.display = "none";
                document.body.appendChild(resdDiv);
            });
        }

        function handleQuerySubmit(e) {
            hideAllPkgSelects();
            e.preventDefault();

            // Show loading message
            document.getElementById('loadingMessage').style.display = 'block';

            // Collect form data
            const formData = new FormData(document.getElementById('queryForm'));
            const params = new URLSearchParams(formData);

            // Build query URL
            const cururl = new URL(window.location.href);
            cururl.pathname = "resjson";

            const currentSearchParams = cururl.searchParams;
            let hasOtherParams = false;
            for (let [key, value] of params) {
                if (key !== 'user' && value.trim() !== '') {
                    if (key === 'pkg') {
                        const currentValue = currentSearchParams.get(key);
                        if (currentValue !== value) {
                            hasOtherParams = true;
                            break;
                        }
                    } else {
                        hasOtherParams = true;
                        break;
                    }
                }
            }
            if (hasOtherParams) {
                //alert(params.toString());
                // Update browser address bar URL (without refreshing the page)
                const newUrl = new URL(window.location.href);
                newUrl.search = params.toString();
                window.history.pushState({}, '', newUrl.toString());
                cururl.search = params.toString();
            }

            // Send request to get new data
            fetch(cururl.toString())
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.json();
                })
                .then(data => {
                    // Update global data
                    testruninfo = data;
                    qresults = testruninfo.qresults;

                    // Hide loading message
                    document.getElementById('loadingMessage').style.display = 'none';

                    // Re-render interface
                    initializeInterface();
                })
                .catch(error => {
                    console.error('Error:', error);
                    // If loading fails, also hide loading message
                    //document.getElementById('loadingMessage').style.display = 'none';
                    document.getElementById('loadingMessage').innerHTML = '<div style="color: red;">Query fail, please try again.</div>';
                });
        }

        // after page loaded
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('loadingMessage').style.display = 'block';

            const cururl = new URL(window.location.href);
            cururl.pathname += "resjson";
            var resurl = cururl.toString();

            function fetchWithRetry(url, retries = 3, delay = 1000) {
                return fetch(url)
                    .then(response => {
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        return response.json();
                    })
                    .catch(error => {
                        if (retries > 0) {
                            console.warn(`Fetch failed, ${retries} retries left. Retrying in ${delay}ms...`, error);
                            return new Promise(resolve => {
                                setTimeout(() => {
                                    resolve(fetchWithRetry(url, retries - 1, delay * 1.5));
                                }, delay);
                            });
                        } else {
                            throw error;
                        }
                    });
            }

            fetchWithRetry(resurl, 3)
                .then(data => {
                    testruninfo = data;
                    qresults = testruninfo.qresults;
                    document.getElementById('loadingMessage').style.display = 'none';
                    initializeInterface();
                })
                .catch(error => {
                    console.error('Error after all retries:', error);
                    // If loading fails, also hide loading message
                    //document.getElementById('loadingMessage').style.display = 'none';
                    document.getElementById('loadingMessage').innerHTML = '<div style="color: red;">loading data fail, please refresh the page and try again.</div>';
                });

            // Query button event
            document.getElementById('queryForm').addEventListener('submit', handleQuerySubmit);
        });
    </script>
</body>
  }
  common-footer $quser
}

proc wapp-page-resjson {} {
  wapp-allow-xorigin-params
  wapp-mimetype application/json
  set quser [get_query_user]
  set qpkg [lindex [wapp-param pkg] 0]
  set runList [wapp-param run-$qpkg]
  set resgenfile "/usr/local/libexec/wapp-trms-resjson.tcl"
  set json [exec expect $resgenfile $quser $qpkg $runList]
  wapp $json; return
  wapp {{
      "components": ["nfs", "cifs"],
      "test-run": {
          "nfs": [
              "rhel-8.10 NFS run for performance testing",
              "rhel-9.8 NFS run for compatibility testing",
              "rhel-10.2 NFS run for security testing",
              "rhel-10.2 ONTAP run for security tls testing"
          ],
          "cifs": [
              "RHEL-8 CIFS run for file sharing",
              "RHEL-9 CIFS run for authentication",
              "RHEL-10 CIFS run for encryption",
              "RHEL-10 Win2k22 run for network stability x86_64, abcd, efg, hijk, xyz",
              "RHEL-10 ONTAP run for network stability x86_64, abcd, uvw, hello, world"
          ]
      },
      "qresults": {
          "qruns": [
              "Test Run 1 - 2025-06-01 from wapp-page-resjon demo data",
              "Test Run 2 - 2025-06-05",
              "Test Run 3 - 2025-06-10",
              "Test Run 4 - 2025-06-15",
              "Test Run 5 - 2025-06-20",
              "Test Run 6 - 2025-06-25",
              "Test Run 7 - 2025-06-30",
              "Test Run 8 - 2025-07-05",
              "Test Run 9 - 2025-07-10",
              "Test Run 10 - 2025-07-15"
          ],
          "results": []
      }
  }}
}

proc wapp-page-main {} {
  wapp-allow-xorigin-params
  wapp-content-security-policy {
    style-src 'self' 'unsafe-inline';
  }

  set uri [wapp-param BASE_URL]
  set logged_user [get_logged_user]

  wapp {<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  }
  common-header $logged_user
  wapp-trim {
</head>
<body>
  <style>
    #p2 {
      text-indent: 2em;
    }
    .warn {
      color: red;
    }
  </style>
  }

  wapp {<font size="+1">}
  set users [exec bash -c {ls /home/*/.testrundb/testrun.db 2>/dev/null|awk -F/ '{print $3}'}]
  if {[llength $users] > 0} {
    wapp {<p id="p2">Now available test run robot instance[s]:<br></p>}
    foreach u $users {
      wapp-subst {<p id="p2"><B>&emsp;<a href="%url($uri?user=$u)">%html(${u})'s test robot instance</a></B>}
      exec -ignorestderr bash -c "crontab -l -u $u || echo | crontab -u $u -"
      set robotinfo [exec bash -c "crontab -l -u $u | sed -n '/^\[\[:space:]]*\[^#].*bkr-autorun-monitor/{p}'; :"]
      if {$robotinfo == ""} {set robotinfo "{warn} robot instance has been disabled"}
      wapp-subst {&emsp;&emsp;-> %html($robotinfo) </p>}
      set krb5stat [exec bash -c "su - $u -c 'klist -s' &>/dev/null && echo valid || echo expired"]
      if {$krb5stat == "expired"} {
        set krb5auth [exec bash -c "c=/home/$u/.beaker_client/config; test -f \$c && awk -F= '/^(USERNAME|KRB_PRINCIPAL)/{print \$2}' \$c|xargs; :"]
        if {$krb5auth != ""} {
          wapp-subst {<p>&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat; krb5 auth: $krb5auth)</p>}
        } else {
          wapp-subst {<p class="warn">&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat);</p>}
        }
      } else {
        set krb5u [exec bash -c "su - $u -c 'klist -l|awk \"NR==3{print \\\$1}\"' 2>/dev/null | tail -1"]
        wapp-subst {<p>&emsp;&emsp;&emsp;&emsp; krb5 ticket: %html($krb5stat ($krb5u))</p>}
      }
    }
  } else {
    wapp-subst {<p id="p2">There is not any test run created by any user, please create test run from command line by using:<br></p>
      <p id="p2"><B>&emsp;bkr-autorun-create $distro $testlist_file {--pkg pkgname} [other bkr-runtest options]</B> <br></p>
      <p id="p2">please see <a href="https://github.com/tcler/bkr-client-improved">bkr-client-improved</a> for more information <br><br><br></p>
    }
  }
  wapp {<br><br><br><br>
    </font>
<body>
  }
  common-footer
}

proc wapp-page-resubmit-list {} {
  wapp-allow-xorigin-params
  set permission yes

  set logged_user [get_logged_user]
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} { set quser $logged_user }
  set dbfile [dbroot $quser]/testrun.db
  if {$logged_user == "" || $logged_user != $quser} {
    set permission no
  }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach test [split $testList "\n"] {
			if {$test == ""} continue
			set testid_ [lindex $test 0]
			set distro_gset_ [lrange $test 1 end]
			set sql {
				UPDATE OR IGNORE testrun
					set jobid='', testStat='', res='o', rstat='', taskuri='', abortedCnt=0, resdetail=''
					WHERE testid = $testid_ and distro_rgset = $distro_gset_;
				INSERT OR IGNORE INTO testrun (testid, distro_rgset, abortedCnt, res, testStat)
					VALUES($testid_, $distro_gset_, 0, '-', '')
			}
			db eval $sql
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-deltest {} {
  wapp-allow-xorigin-params
  set permission yes

  set logged_user [get_logged_user]
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} { set quser $logged_user }
  set dbfile [dbroot $quser]/testrun.db
  if {$logged_user == "" || $logged_user != $quser} {
    set permission no
  }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach test [split $testList "&"] {
			if {$test == ""} continue
			set testid_ [lindex $test 0]
			set distro_gset_ [lrange $test 1 end]

			db eval "DELETE FROM testrun WHERE testid = '$testid_' and distro_rgset = '$distro_gset_'"
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-clone {} {
  wapp-allow-xorigin-params
  set permission yes

  set logged_user [get_logged_user]
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} { set quser $logged_user }
  set dbfile [dbroot $quser]/testrun.db
  if {$logged_user == "" || $logged_user != $quser} {
    set permission no
  }

  wapp {<html>}
  set testList [lindex [wapp-param testlist] 0]
  set distro_gset [wapp-param distro]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != "" && $distro_gset != ""} {
	set distro [lindex $distro_gset 0]
	set gset {}
	set infohead {info:}

	if {[lsearch -regexp $distro_gset ^$infohead] == -1} {
		lappend distro_gset info:kernel
	}

	foreach v [lrange $distro_gset 1 end] {
		if [regexp -- {^-} $v] {
			lappend gset $v
			continue
		} elseif [regexp -- "^$infohead" $v] {
			set infoheadlen [string length $infohead]
			set pkglist [split [string range $v $infoheadlen end] ,]
			if {[lsearch -regexp $pkglist ^kernel$] == -1} {
				set pkglist [linsert $pkglist 0 kernel]
			}
			set info {}
			if [regexp -- "family" $distro] {
				set info [clock format [clock second] -format %Y-%m-%d]
			} else {
				foreach pkg $pkglist {
					append info "[exec bash -c "distro-compose -p ^$pkg-\[0-9] -d ^$distro$|sed -n 2p"],"
				}
			}
			lappend gset -info=$info
		} else {
			if {[regexp -- {^kernel-} $v]} {
				lappend gset -nvr=$v
			} else {
				lappend gset -install=$v
			}
		}
	}
	set distro_gset_ [concat $distro $gset]

	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach testid_ [split $testList ";"] {
			if {$testid_ == ""} continue
			set sql {
				UPDATE OR IGNORE testrun
				    set jobid='', testStat='', res='o', rstat='', taskuri='', abortedCnt=0, resdetail=''
				    WHERE testid = $testid_ and distro_rgset = $distro_gset_;
				INSERT OR IGNORE INTO testrun (testid, distro_rgset, abortedCnt, res, testStat)
				    VALUES($testid_, $distro_gset_, 0, '-', '')
			}
			db eval $sql
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set newRunQuery "run-[wapp-param pkg]=[string map {= %3D { } +} $distro_gset_]"
  set ourl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  set nurl "$ourl&$newRunQuery"
  wapp-subst {return to %unsafe($nurl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($nurl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-delTestCase {} {
  wapp-allow-xorigin-params
  set permission yes

  set logged_user [get_logged_user]
  set quser [lindex [wapp-param user] end]
  if {$quser == {}} { set quser $logged_user }
  set dbfile [dbroot $quser]/testrun.db
  if {$logged_user == "" || $logged_user != $quser} {
    set permission no
  }

  wapp {<html>}
  set testList [wapp-param testlist]
  if {$permission != yes} {
	wapp {<span style="font-size:400%;">You have no permission to do this!<br></span>}
  } elseif {![file exists $dbfile]} {
	wapp {<span style="font-size:400%;">There is not dbfile, something is wrong!<br></span>}
  } elseif {$testList != ""} {
	sqlite3 db $dbfile
	db timeout 6000
	db transaction {
		foreach testid [split $testList ";"] {
			if {$testid == ""} continue
			db eval "DELETE FROM testrun WHERE testid = '$testid'"
		}
	}
	wapp {<span style="font-size:400%;">Update ... Done!<br></span>}
  }

  set defaultUrl "[wapp-param BASE_URL]?[wapp-param QUERY_STRING]"
  wapp-subst {return to %unsafe($defaultUrl)}
  wapp-subst {
	<head>
	<META HTTP-EQUIV="Refresh" CONTENT="1; URL=%unsafe($defaultUrl)">
	</head>
	<body></body>
	</html>
  }
}

proc wapp-page-host-usage {} {
  wapp-allow-xorigin-params
  set quser [get_query_user]
  set hostinfo [::runtestlib::hostUsed $quser]
  set serveraddr [wapp-param HTTP_HOST]
  set clientip [wapp-param REMOTE_ADDR]
  wapp-subst {{
    "hostusage": "%unsafe($hostinfo)",
    "servaddr": "%unsafe($serveraddr)",
    "clntip": "%unsafe($clientip)"
  }}
}

wapp-start $argv
