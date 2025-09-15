// RSG Taxi System JavaScript

// Global Variables
let config = {};
let currentRating = 0;
let selectedDestination = null;
let selectedDriver = null;
let currentTip = 0;
let fareData = {};

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();
    initializeUI();
});

// Setup Event Listeners
function setupEventListeners() {
    // Star rating
    const stars = document.querySelectorAll('.star-rating i');
    stars.forEach((star, index) => {
        star.addEventListener('click', () => setRating(index + 1));
        star.addEventListener('mouseenter', () => highlightStars(index + 1));
    });
    
    document.querySelector('.star-rating').addEventListener('mouseleave', () => {
        highlightStars(currentRating);
    });
    
    // Payment method selection
    const paymentOptions = document.querySelectorAll('input[name="paymentMethod"]');
    paymentOptions.forEach(option => {
        option.addEventListener('change', updatePaymentMethod);
    });
    
    // Custom tip input
    document.getElementById('customTip').addEventListener('input', function() {
        const value = parseFloat(this.value) || 0;
        setTip(value);
    });
    
    // History filters
    document.getElementById('historyFilter').addEventListener('change', filterHistory);
    document.getElementById('historyPeriod').addEventListener('change', filterHistory);
    
    // Close modals on backdrop click
    document.querySelectorAll('.modal-backdrop').forEach(backdrop => {
        backdrop.addEventListener('click', function() {
            const modal = this.parentElement;
            closeModal(modal.id);
        });
    });
    
    // Escape key to close modals
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeAllModals();
        }
    });
}

// Initialize UI
function initializeUI() {
    // Hide all modals initially
    closeAllModals();
    
    // Initialize meter
    updateMeterDisplay(0, 0, 0, false);
}

// NUI Message Handler
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'init':
            config = data.config;
            break;
            
        case 'showMeter':
            showTaxiMeter(data.data);
            break;
            
        case 'hideMeter':
            hideTaxiMeter();
            break;
            
        case 'updateMeter':
            updateMeterDisplay(data.data.fare, data.data.distance, data.data.time, data.data.active);
            break;
            
        case 'showPayment':
            showPaymentUI(data.data);
            break;
            
        case 'hidePayment':
            hidePaymentUI();
            break;
            
        case 'showRating':
            showRatingUI(data.data);
            break;
            
        case 'hideRating':
            hideRatingUI();
            break;
            
        case 'showDashboard':
            showDriverDashboard(data.data);
            break;
            
        case 'hideDashboard':
            hideDriverDashboard();
            break;
            
        case 'showRequest':
            showTaxiRequestUI(data.data);
            break;
            
        case 'hideRequest':
            hideTaxiRequestUI();
            break;
            
        case 'showHistory':
            showRideHistoryUI(data.data);
            break;
            
        case 'hideHistory':
            hideRideHistoryUI();
            break;
            
        case 'showNotification':
            showNotification(data.data.message, data.data.type, data.data.duration);
            break;
            
        case 'updateRideStatus':
            updateRideStatus(data.data.status, data.data.rideData);
            break;
    }
});

// Taxi Meter Functions
function showTaxiMeter(data) {
    const meter = document.getElementById('taxiMeter');
    meter.classList.remove('hidden');
    updateMeterDisplay(data.fare, data.distance, data.time, data.active);
}

function hideTaxiMeter() {
    const meter = document.getElementById('taxiMeter');
    meter.classList.add('hidden');
}

function updateMeterDisplay(fare, distance, time, active) {
    document.getElementById('currentFare').textContent = fare.toFixed(2);
    document.getElementById('tripDistance').textContent = distance.toFixed(1);
    document.getElementById('tripTime').textContent = formatTime(time);
    
    const statusIndicator = document.querySelector('.status-indicator');
    const statusText = document.querySelector('.status-text');
    
    if (active) {
        statusIndicator.classList.add('active');
        statusText.textContent = 'Active';
    } else {
        statusIndicator.classList.remove('active');
        statusText.textContent = 'Inactive';
    }
}

// Payment UI Functions
function showPaymentUI(data) {
    fareData = data;
    const modal = document.getElementById('paymentUI');
    
    // Populate payment data
    document.getElementById('paymentDriverName').textContent = data.driver || '-';
    document.getElementById('paymentDistance').textContent = (data.distance || 0).toFixed(1) + 'm';
    document.getElementById('paymentDuration').textContent = formatTime(data.duration || 0);
    
    // Fare breakdown
    const baseFare = data.baseFare || 0;
    const distanceFare = data.distanceFare || 0;
    const timeFare = data.timeFare || 0;
    const totalFare = data.fare || (baseFare + distanceFare + timeFare);
    
    document.getElementById('baseFare').textContent = baseFare.toFixed(2);
    document.getElementById('distanceFare').textContent = distanceFare.toFixed(2);
    document.getElementById('timeFare').textContent = timeFare.toFixed(2);
    document.getElementById('totalFare').textContent = totalFare.toFixed(2);
    
    // Reset tip
    setTip(0);
    
    modal.classList.remove('hidden');
}

function hidePaymentUI() {
    const modal = document.getElementById('paymentUI');
    modal.classList.add('hidden');
}

function setTip(amount) {
    currentTip = amount;
    document.getElementById('tipAmount').textContent = amount.toFixed(2);
    document.getElementById('customTip').value = amount > 0 ? amount.toFixed(2) : '';
    updateFinalAmount();
    
    // Update tip button states
    document.querySelectorAll('.tip-btn').forEach(btn => btn.classList.remove('active'));
}

function setTipPercent(percent) {
    const totalFare = parseFloat(document.getElementById('totalFare').textContent);
    const tipAmount = totalFare * (percent / 100);
    setTip(tipAmount);
    
    // Highlight selected button
    document.querySelectorAll('.tip-btn').forEach(btn => btn.classList.remove('active'));
    event.target.classList.add('active');
}

function setCustomTip() {
    const customAmount = parseFloat(document.getElementById('customTip').value) || 0;
    setTip(customAmount);
}

function updateFinalAmount() {
    const totalFare = parseFloat(document.getElementById('totalFare').textContent);
    const finalAmount = totalFare + currentTip;
    document.getElementById('finalAmount').textContent = finalAmount.toFixed(2);
}

function updatePaymentMethod() {
    // Payment method updated, could add visual feedback here
}

function processPayment() {
    const totalFare = parseFloat(document.getElementById('totalFare').textContent);
    const paymentMethod = document.querySelector('input[name="paymentMethod"]:checked').value;
    
    const paymentData = {
        driverId: fareData.driverId,
        amount: totalFare,
        tip: currentTip,
        paymentMethod: paymentMethod
    };
    
    fetch(`https://${GetParentResourceName()}/payFare`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(paymentData)
    });
}

function closePayment() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

// Rating UI Functions
function showRatingUI(data) {
    const modal = document.getElementById('ratingUI');
    modal.classList.remove('hidden');
    
    // Reset rating
    setRating(0);
    document.getElementById('ratingComment').value = '';
    
    // Store driver ID
    modal.dataset.driverId = data.driverId;
    
    // Set timeout if specified
    if (data.timeout) {
        setTimeout(() => {
            if (!modal.classList.contains('hidden')) {
                closeRating();
            }
        }, data.timeout);
    }
}

function hideRatingUI() {
    const modal = document.getElementById('ratingUI');
    modal.classList.add('hidden');
}

function setRating(rating) {
    currentRating = rating;
    highlightStars(rating);
    
    const ratingTexts = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    document.getElementById('ratingText').textContent = rating > 0 ? ratingTexts[rating] : 'Click to rate';
}

function highlightStars(rating) {
    const stars = document.querySelectorAll('.star-rating i');
    stars.forEach((star, index) => {
        if (index < rating) {
            star.classList.add('active');
        } else {
            star.classList.remove('active');
        }
    });
}

function submitRating() {
    if (currentRating === 0) {
        showNotification('Please select a rating', 'warning');
        return;
    }
    
    const modal = document.getElementById('ratingUI');
    const comment = document.getElementById('ratingComment').value;
    
    const ratingData = {
        driverId: modal.dataset.driverId,
        rating: currentRating,
        comment: comment
    };
    
    fetch(`https://${GetParentResourceName()}/submitRating`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(ratingData)
    });
}

function closeRating() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

// Dashboard Functions
function showDriverDashboard(data) {
    const modal = document.getElementById('driverDashboard');
    
    // Update stats
    if (data.stats) {
        document.getElementById('totalRides').textContent = data.stats.totalRides || 0;
        document.getElementById('totalEarnings').textContent = (data.stats.totalEarnings || 0).toFixed(2);
        document.getElementById('driverRating').textContent = (data.stats.rating || 5.0).toFixed(1);
    }
    
    document.getElementById('todayEarnings').textContent = (data.todayEarnings || 0).toFixed(2);
    
    // Update current ride section
    const currentRideSection = document.getElementById('currentRideSection');
    if (data.currentRide) {
        currentRideSection.style.display = 'block';
        document.getElementById('currentPassenger').textContent = data.currentRide.passengerName || '-';
        document.getElementById('currentDestination').textContent = data.currentRide.destination?.name || '-';
        document.getElementById('currentRideStatus').textContent = data.currentRide.status || '-';
    } else {
        currentRideSection.style.display = 'none';
    }
    
    // Update work toggle button
    const workToggle = document.getElementById('workToggle');
    if (data.isOnDuty) {
        workToggle.innerHTML = '<i class="fas fa-stop"></i><span>Stop Work</span>';
        workToggle.onclick = () => toggleWork(false);
    } else {
        workToggle.innerHTML = '<i class="fas fa-play"></i><span>Start Work</span>';
        workToggle.onclick = () => toggleWork(true);
    }
    
    modal.classList.remove('hidden');
}

function hideDriverDashboard() {
    const modal = document.getElementById('driverDashboard');
    modal.classList.add('hidden');
}

function toggleWork(start) {
    if (start) {
        fetch(`https://${GetParentResourceName()}/startWork`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
        });
    } else {
        fetch(`https://${GetParentResourceName()}/stopWork`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
        });
    }
}

function toggleVehicle() {
    // This would need to check current vehicle status
    fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

function toggleMeter() {
    fetch(`https://${GetParentResourceName()}/toggleMeter`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

function closeDashboard() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

function openHistory() {
    closeDashboard();
    // Request history data
    fetch(`https://${GetParentResourceName()}/getRideHistory`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({limit: 50})
    }).then(response => response.json())
    .then(data => {
        showRideHistoryUI({rides: data});
    });
}

// Request UI Functions
function showTaxiRequestUI(data) {
    const modal = document.getElementById('taxiRequestUI');
    
    // Populate destinations
    const destinationList = document.getElementById('destinationList');
    destinationList.innerHTML = '';
    
    data.locations.forEach(location => {
        const item = document.createElement('div');
        item.className = 'destination-item';
        item.textContent = location.name;
        item.onclick = () => selectDestination(location, item);
        destinationList.appendChild(item);
    });
    
    // Populate drivers
    const driversList = document.getElementById('driversList');
    driversList.innerHTML = '';
    
    if (data.drivers.length === 0) {
        driversList.innerHTML = '<div class="no-drivers">No drivers available</div>';
    } else {
        data.drivers.forEach(driver => {
            const item = document.createElement('div');
            item.className = 'driver-item';
            item.innerHTML = `
                <div class="driver-info">
                    <div class="driver-name">${driver.name}</div>
                    <div class="driver-details">${driver.distance.toFixed(0)}m away • ${driver.totalRides} rides</div>
                </div>
                <div class="driver-rating">
                    <i class="fas fa-star"></i>
                    <span>${driver.rating.toFixed(1)}</span>
                </div>
            `;
            item.onclick = () => selectDriver(driver, item);
            driversList.appendChild(item);
        });
    }
    
    // Reset selections
    selectedDestination = null;
    selectedDriver = null;
    document.getElementById('requestTaxiBtn').disabled = true;
    document.getElementById('fareEstimate').style.display = 'none';
    
    modal.classList.remove('hidden');
}

function hideTaxiRequestUI() {
    const modal = document.getElementById('taxiRequestUI');
    modal.classList.add('hidden');
}

function selectDestination(destination, element) {
    // Remove previous selection
    document.querySelectorAll('.destination-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    // Select new destination
    element.classList.add('selected');
    selectedDestination = destination;
    
    updateRequestButton();
    calculateFareEstimate();
}

function selectDriver(driver, element) {
    // Remove previous selection
    document.querySelectorAll('.driver-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    // Select new driver
    element.classList.add('selected');
    selectedDriver = driver;
    
    updateRequestButton();
}

function updateRequestButton() {
    const button = document.getElementById('requestTaxiBtn');
    button.disabled = !selectedDestination;
}

function calculateFareEstimate() {
    if (!selectedDestination) return;
    
    // Get player coords (would need to be passed from client)
    const playerCoords = {x: 0, y: 0, z: 0}; // Placeholder
    
    fetch(`https://${GetParentResourceName()}/calculateFare`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            pickup: playerCoords,
            destination: selectedDestination.coords
        })
    }).then(response => response.json())
    .then(data => {
        document.getElementById('estimateDistance').textContent = data.distance.toFixed(0) + 'm';
        document.getElementById('estimateTime').textContent = Math.ceil(data.estimatedTime / 60) + ' min';
        document.getElementById('estimateFare').textContent = data.totalFare.toFixed(2);
        document.getElementById('fareEstimate').style.display = 'block';
    });
}

function requestTaxi() {
    if (!selectedDestination) return;
    
    const requestData = {
        pickup: {x: 0, y: 0, z: 0}, // Would get from client
        destination: selectedDestination
    };
    
    fetch(`https://${GetParentResourceName()}/requestTaxi`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData)
    });
}

function closeRequest() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

// History UI Functions
function showRideHistoryUI(data) {
    const modal = document.getElementById('rideHistoryUI');
    
    // Populate history
    const historyList = document.getElementById('historyList');
    historyList.innerHTML = '';
    
    if (data.rides.length === 0) {
        historyList.innerHTML = '<div class="no-history">No ride history found</div>';
    } else {
        data.rides.forEach(ride => {
            const item = document.createElement('div');
            item.className = 'history-item';
            
            const date = new Date(ride.created_at).toLocaleDateString();
            const time = new Date(ride.created_at).toLocaleTimeString();
            const amount = (ride.fare + ride.tip).toFixed(2);
            
            item.innerHTML = `
                <div class="history-header">
                    <div class="history-date">${date} ${time}</div>
                    <div class="history-amount">$${amount}</div>
                </div>
                <div class="history-details">
                    <div>Destination: ${ride.destination_name || 'Unknown'}</div>
                    <div>Distance: ${ride.distance?.toFixed(1) || 0}m</div>
                    <div>Duration: ${formatTime(ride.duration || 0)}</div>
                    <div>Rating: ${ride.rating ? ride.rating + '/5' : 'Not rated'}</div>
                </div>
            `;
            
            historyList.appendChild(item);
        });
    }
    
    modal.classList.remove('hidden');
}

function hideRideHistoryUI() {
    const modal = document.getElementById('rideHistoryUI');
    modal.classList.add('hidden');
}

function filterHistory() {
    // Would implement filtering logic here
    console.log('Filter history');
}

function closeHistory() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
    });
}

// Notification Functions
function showNotification(message, type = 'info', duration = 5000) {
    const container = document.getElementById('notifications');
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    
    const icons = {
        success: 'fas fa-check-circle',
        error: 'fas fa-exclamation-circle',
        warning: 'fas fa-exclamation-triangle',
        info: 'fas fa-info-circle'
    };
    
    notification.innerHTML = `
        <i class="${icons[type] || icons.info}"></i>
        <span>${message}</span>
    `;
    
    container.appendChild(notification);
    
    // Auto remove after duration
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
        }
    }, duration);
}

// Utility Functions
function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('hidden');
    }
}

function closeAllModals() {
    const modals = document.querySelectorAll('.ui-modal');
    modals.forEach(modal => {
        modal.classList.add('hidden');
    });
}

function updateRideStatus(status, data) {
    // Update UI based on ride status
    console.log('Ride status updated:', status, data);
}

// Helper function to get resource name
function GetParentResourceName() {
    return 'rsg-taxi';
}