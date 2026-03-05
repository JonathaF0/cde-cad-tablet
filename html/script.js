let isTabletOpen = false;
let currentSize = 'large';
let frameLoadTimeout = null;
let keepAliveInterval = null;
let retryCount = 0;
const maxRetries = 3;

// Get resource name dynamically
const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'cad_tablet';
console.log('[CAD-TABLET] Resource name:', resourceName);

// Tablet size configurations
const tabletSizes = {
    small: { width: '60vw', height: '70vh', maxWidth: '800px', maxHeight: '600px' },
    medium: { width: '75vw', height: '80vh', maxWidth: '1000px', maxHeight: '700px' },
    large: { width: '85vw', height: '90vh', maxWidth: '1400px', maxHeight: '900px' },
    xlarge: { width: '92vw', height: '94vh', maxWidth: '1800px', maxHeight: '1000px' },
    fullscreen: { width: '98vw', height: '98vh', maxWidth: 'none', maxHeight: 'none' }
};

// Improved frame load handling
function setupFrameLoadHandling(frame, url) {
    // Clear any existing timeout
    if (frameLoadTimeout) {
        clearTimeout(frameLoadTimeout);
    }
    
    // Set a timeout for frame loading
    frameLoadTimeout = setTimeout(() => {
        console.warn('[CAD-TABLET] Frame load timeout');
        handleFrameError('Connection timeout - server may be slow');
    }, 15000); // 15 second timeout
    
    // Handle successful load
    frame.onload = function() {
        console.log('[CAD-TABLET] Frame loaded successfully');
        clearTimeout(frameLoadTimeout);
        
        const loadingScreen = document.getElementById('loading-screen');
        setTimeout(() => {
            loadingScreen.classList.add('hidden');
            retryCount = 0; // Reset retry count on successful load
            
            // Start keep-alive mechanism
            startKeepAlive();
            
            // Try to prevent popups after load
            setTimeout(() => {
                blockPopups();
            }, 2000);
        }, 1000);
    };
    
    // Handle frame errors
    frame.onerror = function() {
        console.error('[CAD-TABLET] Frame load error');
        clearTimeout(frameLoadTimeout);
        handleFrameError('Failed to connect to CAD system');
    };
}

// Handle frame loading errors
function handleFrameError(message) {
    const loadingScreen = document.getElementById('loading-screen');
    
    retryCount++;
    
    if (retryCount <= maxRetries) {
        loadingScreen.innerHTML = `
            <div style="text-align: center;">
                <p style="color: #e74c3c; font-size: 18px; margin-bottom: 10px;">⚠️ ${message}</p>
                <p style="color: #666;">Retrying... (${retryCount}/${maxRetries})</p>
                <div class="loading-spinner" style="margin: 20px auto;"></div>
            </div>
        `;
        
        // Auto retry after 3 seconds
        setTimeout(() => {
            refreshFrame();
        }, 3000);
    } else {
        loadingScreen.innerHTML = `
            <div style="text-align: center;">
                <p style="color: #e74c3c; font-size: 18px; margin-bottom: 10px;">❌ ${message}</p>
                <p style="color: #666;">Unable to connect after ${maxRetries} attempts</p>
                <button onclick="manualRefresh()" style="margin-top: 15px; padding: 8px 16px; background: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer;">
                    Try Again
                </button>
                <button onclick="closeTablet()" style="margin-top: 15px; margin-left: 10px; padding: 8px 16px; background: #e74c3c; color: white; border: none; border-radius: 4px; cursor: pointer;">
                    Close
                </button>
            </div>
        `;
    }
}

// Enhanced popup blocking with exit handling
function blockPopups() {
    const frame = document.getElementById('cad-frame');
    if (!frame || !frame.contentWindow) return;
    
    try {
        const frameWindow = frame.contentWindow;
        
        // Store original functions if they exist
        const originalAlert = frameWindow.alert;
        const originalConfirm = frameWindow.confirm;
        const originalPrompt = frameWindow.prompt;
        const originalOpen = frameWindow.open;
        
        // Override popup functions with smart handling
        frameWindow.alert = function(msg) {
            console.log('[CAD-TABLET] Blocked alert:', msg);
            
            // Send popup info to Lua
            fetch(`https://${resourceName}/popupBlocked`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({type: 'alert', message: msg})
            }).catch(err => console.log('[CAD-TABLET] Popup callback failed:', err));
            
            // Check if it's an exit/logout related alert
            if (msg && (msg.toLowerCase().includes('logout') || 
                       msg.toLowerCase().includes('exit') || 
                       msg.toLowerCase().includes('leave') ||
                       msg.toLowerCase().includes('close'))) {
                console.log('[CAD-TABLET] Exit-related alert detected, closing tablet');
                
                // Send exit detection to Lua
                fetch(`https://${resourceName}/exitDetected`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({reason: 'alert', message: msg})
                }).catch(err => console.log('[CAD-TABLET] Exit callback failed:', err));
                
                setTimeout(() => closeTablet(), 100);
            }
            return undefined;
        };
        
        frameWindow.confirm = function(msg) {
            console.log('[CAD-TABLET] Intercepted confirm:', msg);
            
            // Send popup info to Lua
            fetch(`https://${resourceName}/popupBlocked`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({type: 'confirm', message: msg})
            }).catch(err => console.log('[CAD-TABLET] Popup callback failed:', err));
            
            // Check if it's an exit/logout confirmation
            if (msg && (msg.toLowerCase().includes('logout') || 
                       msg.toLowerCase().includes('exit') || 
                       msg.toLowerCase().includes('leave') ||
                       msg.toLowerCase().includes('close') ||
                       msg.toLowerCase().includes('sure'))) {
                console.log('[CAD-TABLET] Exit confirmation detected, auto-confirming and closing');
                
                // Send exit detection to Lua
                fetch(`https://${resourceName}/exitDetected`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({reason: 'confirm', message: msg})
                }).catch(err => console.log('[CAD-TABLET] Exit callback failed:', err));
                
                setTimeout(() => closeTablet(), 100);
                return true;
            }
            
            // For other confirmations, auto-confirm to prevent blocking
            return true;
        };
        
        frameWindow.prompt = function(msg, defaultText) {
            console.log('[CAD-TABLET] Blocked prompt:', msg);
            return defaultText || '';
        };
        
        frameWindow.open = function(url, target, features) {
            console.log('[CAD-TABLET] Intercepted window.open:', url, target, features);
            
            // Send popup info to Lua
            fetch(`https://${resourceName}/popupBlocked`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({type: 'window.open', url: url, target: target})
            }).catch(err => console.log('[CAD-TABLET] Popup callback failed:', err));
            
            // Check if it's trying to open a logout/exit page
            if (url && (url.includes('logout') || 
                       url.includes('exit') || 
                       url.includes('login') ||
                       url.includes('close'))) {
                console.log('[CAD-TABLET] Exit page detected, closing tablet instead');
                
                // Send exit detection to Lua
                fetch(`https://${resourceName}/exitDetected`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({reason: 'window.open', url: url})
                }).catch(err => console.log('[CAD-TABLET] Exit callback failed:', err));
                
                setTimeout(() => closeTablet(), 100);
                return null;
            }
            
            // If it's trying to open in same window, navigate there instead
            if (target === '_self' || !target) {
                frame.src = url;
                return { closed: false }; // Return a fake window object
            }
            
            // For other popups, return a fake window object to prevent errors
            return {
                closed: false,
                close: function() { console.log('[CAD-TABLET] Fake window close called'); },
                focus: function() { console.log('[CAD-TABLET] Fake window focus called'); },
                blur: function() { console.log('[CAD-TABLET] Fake window blur called'); }
            };
        };
        
        // Enhanced beforeunload handling
        frameWindow.addEventListener('beforeunload', function(e) {
            console.log('[CAD-TABLET] Beforeunload event intercepted');
            e.preventDefault();
            e.returnValue = '';
            
            // If this is triggered, likely user is trying to exit
            setTimeout(() => {
                if (isTabletOpen) {
                    console.log('[CAD-TABLET] Beforeunload suggests exit intent, closing tablet');
                    closeTablet();
                }
            }, 100);
            
            return '';
        });
        
        // Override history methods that might trigger popups
        const originalBack = frameWindow.history.back;
        const originalForward = frameWindow.history.forward;
        
        frameWindow.history.back = function() {
            console.log('[CAD-TABLET] History.back intercepted, might be exit attempt');
            // Instead of going back, close the tablet
            setTimeout(() => closeTablet(), 100);
        };
        
        frameWindow.history.forward = function() {
            console.log('[CAD-TABLET] History.forward intercepted');
            originalForward.call(frameWindow.history);
        };
        
        // Monitor for DOM changes that might indicate logout buttons
        if (frameWindow.document && frameWindow.document.body) {
            const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList') {
                        // Look for logout/exit buttons or modals
                        const addedNodes = Array.from(mutation.addedNodes);
                        addedNodes.forEach(node => {
                            if (node.nodeType === 1) { // Element node
                                const text = node.textContent || node.innerText || '';
                                if (text.toLowerCase().includes('logout') || 
                                    text.toLowerCase().includes('sign out') ||
                                    text.toLowerCase().includes('exit')) {
                                    console.log('[CAD-TABLET] Logout element detected in DOM');
                                }
                            }
                        });
                    }
                });
            });
            
            observer.observe(frameWindow.document.body, {
                childList: true,
                subtree: true
            });
        }
        
    } catch (e) {
        console.log('[CAD-TABLET] Could not override popup functions (cross-origin):', e);
    }
}

// Keep-alive mechanism to ensure tablet stays responsive
function startKeepAlive() {
    if (keepAliveInterval) {
        clearInterval(keepAliveInterval);
    }
    
    keepAliveInterval = setInterval(() => {
        if (!isTabletOpen) {
            clearInterval(keepAliveInterval);
            return;
        }
        
        // Send keep-alive to Lua
        fetch(`https://${resourceName}/keepAlive`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({timestamp: Date.now()})
        }).catch(err => {
            console.log('[CAD-TABLET] Keep-alive failed:', err);
        });
    }, 30000); // Every 30 seconds
}

// Update time display
function updateTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('en-US', { 
        hour12: false,
        hour: '2-digit',
        minute: '2-digit'
    });
    const dateString = now.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric'
    });
    
    const timeElement = document.getElementById('tablet-time');
    if (timeElement) {
        timeElement.textContent = `${timeString} | ${dateString}`;
    }
}

// Handle messages from FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    console.log('[CAD-TABLET] Received message:', data.type);
    
    if (data.type === 'openTablet') {
        openTablet(data.url);
    } else if (data.type === 'closeTablet') {
        closeTablet();
    } else if (data.type === 'forceClose') {
        forceCloseTablet();
    }
});

// Open tablet function
function openTablet(url) {
    if (isTabletOpen) return;
    
    console.log('[CAD-TABLET] Opening tablet with URL:', url);
    
    isTabletOpen = true;
    retryCount = 0;
    
    const container = document.getElementById('tablet-container');
    const frame = document.getElementById('cad-frame');
    const loadingScreen = document.getElementById('loading-screen');
    
    // Show container
    container.classList.remove('hidden');
    container.style.display = 'flex';
    
    // Reset loading screen
    loadingScreen.classList.remove('hidden');
    loadingScreen.innerHTML = `
        <div class="loading-spinner"></div>
        <p>Connecting to CAD System...</p>
    `;
    
    // Setup frame handling before loading
    setupFrameLoadHandling(frame, url);
    
    // Load the CAD website
    frame.src = url;
}

// Close tablet function
function closeTablet() {
    if (!isTabletOpen) return;
    
    console.log('[CAD-TABLET] Closing tablet...');
    
    // Stop keep-alive
    if (keepAliveInterval) {
        clearInterval(keepAliveInterval);
    }
    
    // Clear timeouts
    if (frameLoadTimeout) {
        clearTimeout(frameLoadTimeout);
    }
    
    // Send callback to Lua FIRST
    fetch(`https://${resourceName}/closeTablet`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({})
    }).then(() => {
        console.log('[CAD-TABLET] Callback sent successfully');
    }).catch(err => {
        console.log('[CAD-TABLET] Callback failed:', err);
    }).finally(() => {
        finishCloseTablet();
    });
}

// Finish closing the tablet
function finishCloseTablet() {
    isTabletOpen = false;
    
    const container = document.getElementById('tablet-container');
    const frame = document.getElementById('cad-frame');
    const loadingScreen = document.getElementById('loading-screen');
    
    // Hide container
    container.classList.add('hidden');
    container.style.display = 'none';
    
    // Clear frame
    frame.src = 'about:blank'; // Use about:blank instead of empty string
    
    // Reset loading screen
    loadingScreen.classList.remove('hidden');
    loadingScreen.innerHTML = `
        <div class="loading-spinner"></div>
        <p>Loading CAD System...</p>
    `;
    
    // Reset size to default
    currentSize = 'large';
    applyTabletSize();
    
    console.log('[CAD-TABLET] Interface closed');
}

// Force close tablet function (emergency)
function forceCloseTablet() {
    console.log('[CAD-TABLET] FORCE CLOSING tablet...');
    
    isTabletOpen = false;
    
    // Clear all intervals and timeouts
    if (keepAliveInterval) clearInterval(keepAliveInterval);
    if (frameLoadTimeout) clearTimeout(frameLoadTimeout);
    
    const container = document.getElementById('tablet-container');
    const frame = document.getElementById('cad-frame');
    
    if (container) {
        container.style.display = 'none';
        container.classList.add('hidden');
    }
    
    if (frame) {
        frame.src = 'about:blank';
    }
    
    console.log('[CAD-TABLET] Force close complete');
}

// Manual refresh function (for error recovery)
window.manualRefresh = function() {
    retryCount = 0;
    refreshFrame();
}

// Refresh frame function
window.refreshFrame = function() {
    const frame = document.getElementById('cad-frame');
    const loadingScreen = document.getElementById('loading-screen');
    
    if (!frame || !isTabletOpen) return;
    
    console.log('[CAD-TABLET] Refreshing frame...');
    
    loadingScreen.classList.remove('hidden');
    loadingScreen.innerHTML = `
        <div class="loading-spinner"></div>
        <p>Reconnecting...</p>
    `;
    
    // Clear existing timeouts
    if (frameLoadTimeout) {
        clearTimeout(frameLoadTimeout);
    }
    
    // Get current URL and add cache buster
    const currentUrl = frame.src;
    const separator = currentUrl.includes('?') ? '&' : '?';
    const newUrl = currentUrl + separator + 'refresh=' + Date.now();
    
    // Setup new handling
    setupFrameLoadHandling(frame, newUrl);
    
    // Reload with cache buster
    frame.src = newUrl;
}

// Apply tablet size
function applyTabletSize() {
    const tabletFrame = document.querySelector('.tablet-frame');
    if (!tabletFrame) return;
    
    const config = tabletSizes[currentSize];
    
    tabletFrame.style.width = config.width;
    tabletFrame.style.height = config.height;
    tabletFrame.style.maxWidth = config.maxWidth;
    tabletFrame.style.maxHeight = config.maxHeight;
    
    // Update UI indicators
    const sizeText = currentSize === 'xlarge' ? 'XLarge' : 
                     currentSize === 'fullscreen' ? 'Full' :
                     currentSize.charAt(0).toUpperCase() + currentSize.slice(1);
    
    const resizeBtn = document.getElementById('resize-btn');
    const sizeIndicator = document.getElementById('size-indicator');
    
    if (resizeBtn) resizeBtn.title = `Resize (${sizeText})`;
    if (sizeIndicator) sizeIndicator.textContent = sizeText;
}

// Resize tablet function
function resizeTablet() {
    const sizes = Object.keys(tabletSizes);
    const currentIndex = sizes.indexOf(currentSize);
    const nextIndex = (currentIndex + 1) % sizes.length;
    currentSize = sizes[nextIndex];
    applyTabletSize();
}

// Toggle fullscreen
function toggleFullscreen() {
    currentSize = currentSize === 'fullscreen' ? 'large' : 'fullscreen';
    applyTabletSize();
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('[CAD-TABLET] DOM loaded, setting up event listeners');
    
    // Initialize time display
    updateTime();
    setInterval(updateTime, 1000);
    
    // Setup event listeners
    const closeBtn = document.getElementById('close-btn');
    const refreshBtn = document.getElementById('refresh-btn');
    const resizeBtn = document.getElementById('resize-btn');
    const fullscreenBtn = document.getElementById('fullscreen-btn');
    
    if (closeBtn) {
        closeBtn.addEventListener('click', () => {
            console.log('[CAD-TABLET] Close button clicked');
            closeTablet();
        });
    }
    
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => refreshFrame());
    }
    
    if (resizeBtn) {
        resizeBtn.addEventListener('click', () => resizeTablet());
    }
    
    if (fullscreenBtn) {
        fullscreenBtn.addEventListener('click', () => toggleFullscreen());
    }
    
    // Initialize tablet size
    applyTabletSize();
});

// Keyboard event handlers
document.addEventListener('keydown', function(event) {
    if (!isTabletOpen) return;
    
    if (event.key === 'Escape') {
        console.log('[CAD-TABLET] ESC key pressed in NUI');
        closeTablet();
    }
    
    // Alt+F4, Ctrl+W prevention
    if ((event.altKey && event.key === 'F4') || 
        (event.ctrlKey && event.key === 'w')) {
        event.preventDefault();
        closeTablet();
    }
    
    // F11 for fullscreen toggle
    if (event.key === 'F11') {
        event.preventDefault();
        toggleFullscreen();
    }
    
    // F5 for refresh
    if (event.key === 'F5') {
        event.preventDefault();
        refreshFrame();
    }
});

// Prevent right-click context menu
document.addEventListener('contextmenu', function(event) {
    event.preventDefault();
});

// Enhanced message blocking from iframe with exit detection
window.addEventListener('message', function(event) {
    const frame = document.getElementById('cad-frame');
    if (!frame || event.source !== frame.contentWindow) return;
    
    // Block popup-related messages from iframe
    if (event.data && typeof event.data === 'object') {
        console.log('[CAD-TABLET] Iframe message:', event.data);
        
        // Check for exit/logout related messages
        if (event.data.type) {
            const messageType = event.data.type.toLowerCase();
            const messageText = JSON.stringify(event.data).toLowerCase();
            
            // Detect logout/exit attempts
            if (messageType.includes('logout') || 
                messageType.includes('exit') || 
                messageType.includes('close') ||
                messageText.includes('logout') ||
                messageText.includes('exit') ||
                messageText.includes('sign out')) {
                
                console.log('[CAD-TABLET] Exit message detected, closing tablet');
                event.preventDefault();
                event.stopPropagation();
                setTimeout(() => closeTablet(), 100);
                return false;
            }
            
            // Block all popup types
            if (['popup', 'alert', 'confirm', 'open', 'modal', 'dialog'].includes(messageType)) {
                console.log('[CAD-TABLET] Blocked popup message from iframe:', event.data);
                event.preventDefault();
                event.stopPropagation();
                return false;
            }
        }
        
        // Check message content for exit keywords
        const messageStr = JSON.stringify(event.data).toLowerCase();
        if (messageStr.includes('logout') || 
            messageStr.includes('sign out') || 
            messageStr.includes('exit') ||
            messageStr.includes('leave page')) {
            console.log('[CAD-TABLET] Exit content detected in message, closing tablet');
            event.preventDefault();
            event.stopPropagation();
            setTimeout(() => closeTablet(), 100);
            return false;
        }
    }
}, true);

// Handle page visibility changes (alt-tab detection)
document.addEventListener('visibilitychange', function() {
    if (document.hidden && isTabletOpen) {
        console.log('[CAD-TABLET] Page hidden, pausing keep-alive');
        if (keepAliveInterval) {
            clearInterval(keepAliveInterval);
        }
    } else if (!document.hidden && isTabletOpen) {
        console.log('[CAD-TABLET] Page visible, resuming keep-alive');
        startKeepAlive();
    }
});

console.log('[CAD-TABLET] Enhanced script loaded and ready');
