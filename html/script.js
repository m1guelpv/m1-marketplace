const CURRENCY_FORMAT = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const DATE_FORMAT = new Intl.DateTimeFormat("en-US", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

const DEFAULT_SORT_ATTRIBUTE = "date";
const DEFAULT_SORT_DIRECTION = "desc";

const MarketPlaceApp = Vue.createApp({
  data() {
    return {
      isMarketOpen: false,
      activeSection: "browseMarket",
      sections: {
        browseMarket: [],
        yourOffers: [],
        transactionHistory: [],
      },
      searchQuery: {
        browseMarket: "",
        yourOffers: "",
        transactionHistory: "",
      },
      newOffer: { name: "", quantity: 0, unitPrice: 0 },
      selectedOffer: {},
      activeModal: "",
      activeSort: DEFAULT_SORT_ATTRIBUTE,
      sortDirection: DEFAULT_SORT_DIRECTION,
      sortableAttributes: [
        { name: "name", label: "Name" },
        { name: "quantity", label: "Quantity" },
        { name: "unitPrice", label: "Unit Price" },
        { name: "date", label: "Date" },
      ],
      playerData: { name: "", bank: 0, inventory: [] },
      settings: {},
    };
  },
  methods: {
    handleMessage(event) {
      const { action, settings, playerData, marketData } = event.data;
      if (action === "openMarket") {
        this.sections.browseMarket = marketData;
        this.sections.yourOffers = playerData.offers;
        this.sections.transactionHistory = playerData.history;
        this.playerData = playerData;
        this.settings = settings;
        this.isMarketOpen = true;
        return;
      }
      if (action === "updateMarketData") {
        this.sections.browseMarket = marketData;
        return;
      }
      if (action === "updatePlayerData") {
        this.playerData = playerData;
        this.sections.yourOffers = playerData.offers;
        this.sections.transactionHistory = playerData.history;
        return;
      }
    },
    handleKeydown(event) {
      if (event.key === "Escape") {
        this.closeMarket();
      }
    },
    formatCurrency(value) {
      return CURRENCY_FORMAT.format(value);
    },
    formatSqlDate(timestamp) {
      return DATE_FORMAT.format(new Date(Number(timestamp)));
    },
    filteredOffers() {
      const query = this.searchQuery[this.activeSection].toLowerCase();
      return (
        this.sections[this.activeSection]
          ?.filter((item) => {
            if (this.activeSection === "browseMarket" && item.sellerId === this.playerData.id) {
              return false;
            }
            return item.label.toLowerCase().includes(query);
          })
          .sort(this.compareAttributes) || []
      );
    },
    compareAttributes(a, b) {
      const attribute = this.activeSort;
      const valueA = attribute === "date" ? a.createdAt || a.finishedAt : a[attribute];
      const valueB = attribute === "date" ? b.createdAt || b.finishedAt : b[attribute];
      if (valueA < valueB) return this.sortDirection === "asc" ? -1 : 1;
      if (valueA > valueB) return this.sortDirection === "asc" ? 1 : -1;
      return 0;
    },
    changeSection(section) {
      this.activeSection = section;
    },
    toggleSort(attribute) {
      if (this.activeSort === attribute) {
        this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
      } else {
        this.activeSort = attribute;
        this.sortDirection = DEFAULT_SORT_DIRECTION;
      }
    },
    getSortIcon(attribute) {
      if (this.activeSort === attribute) {
        return this.sortDirection === "asc" ? "fa-sort-up" : "fa-sort-down";
      }
      return "fa-sort";
    },
    offerClaimed(offer) {
      if (offer.sellerId === this.playerData.id && offer.sellerClaimed) {
        return "seller";
      }
      if (offer.buyerId === this.playerData.id && offer.buyerClaimed) {
        return "buyer";
      }
      return false;
    },
    openModal(modal, offer = {}) {
      if (modal === "transactionHistory" && this.offerClaimed(offer)) {
        return;
      }
      this.selectedOffer = offer;
      this.activeModal = modal;
    },
    declineModal() {
      this.activeModal = "";
    },
    acceptModal() {
      const actions = {
        createOffer: () => this.createOffer(),
        browseMarket: () => this.buyOffer(),
        yourOffers: () => this.removeOffer(),
        transactionHistory: () => this.claimOffer(),
      };
      actions[this.activeModal]?.();
      this.activeModal = "";
    },
    createOffer() {
      axios
        .post(`https://${GetParentResourceName()}/createOffer`, {
          item: this.newOffer.name,
          quantity: this.newOffer.quantity,
          unitPrice: this.newOffer.unitPrice,
        })
        .then((response) => {
          if (response.data.status === "success") {
            this.newOffer = { name: "", quantity: 0, unitPrice: 0 };
          }
        });
    },
    buyOffer() {
      axios
        .post(`https://${GetParentResourceName()}/buyOffer`, {
          id: this.selectedOffer.id,
        })
        .then((response) => {
          if (response.data.status === "success") {
            this.selectedOffer = {};
          }
        });
    },
    removeOffer() {
      axios
        .post(`https://${GetParentResourceName()}/removeOffer`, {
          id: this.selectedOffer.id,
        })
        .then((response) => {
          if (response.data.status === "success") {
            this.selectedOffer = {};
          }
        });
    },
    claimOffer() {
      axios
        .post(`https://${GetParentResourceName()}/claimOffer`, {
          id: this.selectedOffer.id,
        })
        .then((response) => {
          if (response.data.status === "success") {
            this.selectedOffer = {};
          }
        });
    },
    getItemImage(name) {
      return `nui://qb-inventory/html/images/${name}.png`;
    },
    closeMarket() {
      this.resetVariables();
      axios.post(`https://${GetParentResourceName()}/closeMarket`);
    },
    resetVariables() {
      this.isMarketOpen = false;
      this.activeSection = "browseMarket";
      this.sections = {
        browseMarket: [],
        yourOffers: [],
        transactionHistory: [],
      };
      this.searchQuery = {
        browseMarket: "",
        yourOffers: "",
        transactionHistory: "",
      };
      this.newOffer = { name: "", quantity: 0, unitPrice: 0 };
      this.selectedOffer = {};
      this.activeModal = "";
      this.activeSort = DEFAULT_SORT_ATTRIBUTE;
      this.sortDirection = DEFAULT_SORT_DIRECTION;
      this.playerData = { name: "", bank: 0, inventory: [] };
    },
  },
  watch: {
    "newOffer.quantity"(newVal) {
      if (newVal < 0) {
        this.newOffer.quantity = 0;
      } else if (newVal > this.settings.maxQuantity) {
        this.newOffer.quantity = this.settings.maxQuantity;
      }
    },
    "newOffer.unitPrice"(newVal) {
      if (newVal < 0) {
        this.newOffer.unitPrice = 0;
      } else if (newVal > this.settings.maxPrice) {
        this.newOffer.unitPrice = this.settings.maxPrice;
      }
    },
  },
  mounted() {
    window.addEventListener("message", this.handleMessage);
    document.addEventListener("keydown", this.handleKeydown);
  },
}).mount("#app");