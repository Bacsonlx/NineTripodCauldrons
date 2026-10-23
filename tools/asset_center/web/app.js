/**
 * 九鼎 · 十日 | 资产管理中心 Web 前端交互引擎
 * Single-Page Reactive Hub without external frameworks
 */

(function () {
  'use strict';

  // Application State
  const state = {
    assets: [],
    gameplay: {
      items: [],
      characters: [],
      vessels: []
    },
    stats: {},
    mediaCatalog: [],
    filters: {
      search: '',
      category: 'ALL',
      stage: 'ALL',
      status: 'ALL',
      hasMedia: false
    },
    activeTab: 'tab-dashboard',
    viewMode: 'grid', // 'grid' | 'table'
    selectedAsset: null,
    
    // Media Workshop State
    workshop: {
      activeAssetId: null,
      activeMediaIndex: 0,
      zoom: 1.0,
      isChecker: false,
      isPlaying: false,
      fps: 10,
      timer: null
    }
  };

  // Category Icon Map for Aesthetics
  const categoryIcons = {
    '人物': '👤',
    'Boss 与对手': '👹',
    '普通敌人与召唤物': '👺',
    '武器与装备': '🏹',
    '道具与收集物': '🏺',
    '建筑与场景构件': '🏛️',
    '树木与植被': '🌲',
    '地形与环境': '⛰️',
    '环境小物与贴花': '🪨',
    '视觉特效': '✨',
    '界面与图标': '📐',
    '肖像与展示图': '🖼️',
    '叙事画面与结局': '📜'
  };

  // DOM Elements
  const el = {
    globalSearch: document.getElementById('global-search'),
    liveStatus: document.getElementById('live-status'),
    navTabs: document.querySelectorAll('.nav-tab'),
    tabPanes: document.querySelectorAll('.tab-pane'),
    
    // Dashboard
    statTotal: document.getElementById('stat-total'),
    statSlice: document.getElementById('stat-slice'),
    statMedia: document.getElementById('stat-media'),
    statGameplay: document.getElementById('stat-gameplay'),
    stageBreakdownList: document.getElementById('stage-breakdown-list'),
    statusBreakdownList: document.getElementById('status-breakdown-list'),
    vesselsMatrix: document.getElementById('vessels-matrix'),
    categoryCardsGrid: document.getElementById('category-cards-grid'),
    
    // Art Catalog
    categoryPills: document.getElementById('category-pills'),
    selectStage: document.getElementById('select-stage'),
    selectStatus: document.getElementById('select-status'),
    checkHasMedia: document.getElementById('check-has-media'),
    btnViewGrid: document.getElementById('btn-view-grid'),
    btnViewTable: document.getElementById('btn-view-table'),
    artGridView: document.getElementById('art-grid-view'),
    artTableView: document.getElementById('art-table-view'),
    artTableBody: document.getElementById('art-table-body'),
    filteredCount: document.getElementById('filtered-count'),
    
    // Gameplay
    gameplayCharsGrid: document.getElementById('gameplay-characters-grid'),
    gameplaySkillsGrid: document.getElementById('gameplay-skills-grid'),
    gameplayItemsGrid: document.getElementById('gameplay-items-grid'),
    gameplayVesselsGrid: document.getElementById('gameplay-vessels-grid'),
    subnavBtns: document.querySelectorAll('.subnav-btn'),
    subtabPanes: document.querySelectorAll('.subtab-pane'),
    itemFilterPills: document.querySelectorAll('.item-filter-pill'),

    // Workshop
    workshopAssetList: document.getElementById('workshop-asset-list'),
    playerAssetId: document.getElementById('player-asset-id'),
    playerAssetName: document.getElementById('player-asset-name'),
    playerFilename: document.getElementById('player-filename'),
    playerImg: document.getElementById('player-img'),
    playerViewport: document.getElementById('player-viewport'),
    viewportCanvasWrap: document.getElementById('viewport-canvas-wrap'),
    mediaThumbnailsStrip: document.getElementById('media-thumbnails-strip'),
    btnPlayPause: document.getElementById('btn-play-pause'),
    btnStepPrev: document.getElementById('btn-step-prev'),
    btnStepNext: document.getElementById('btn-step-next'),
    selectFps: document.getElementById('select-fps'),
    btnPlayerChecker: document.getElementById('btn-player-checker'),
    btnZoomIn: document.getElementById('btn-zoom-in'),
    btnZoomOut: document.getElementById('btn-zoom-out'),
    btnZoomFit: document.getElementById('btn-zoom-fit'),
    zoomText: document.getElementById('zoom-text'),

    // Drawer
    assetDrawer: document.getElementById('asset-drawer'),
    drawerOverlay: document.getElementById('drawer-overlay'),
    btnDrawerClose: document.getElementById('btn-drawer-close'),
    btnDrawerCancel: document.getElementById('btn-drawer-cancel'),
    btnDrawerSave: document.getElementById('btn-drawer-save'),
    drawerId: document.getElementById('drawer-id'),
    drawerName: document.getElementById('drawer-name'),
    drawerMediaGallery: document.getElementById('drawer-media-gallery'),
    drawerMediaSection: document.getElementById('drawer-media-section'),
    
    // Drawer Inputs
    editCategory: document.getElementById('edit-category'),
    editSubcategory: document.getElementById('edit-subcategory'),
    editStage: document.getElementById('edit-stage'),
    editStatus: document.getElementById('edit-status'),
    editRegion: document.getElementById('edit-region'),
    editPurpose: document.getElementById('edit-purpose'),
    editForms: document.getElementById('edit-forms'),
    editBasis: document.getElementById('edit-basis'),
    editSource: document.getElementById('edit-source'),
    editReuse: document.getElementById('edit-reuse'),
    editNotes: document.getElementById('edit-notes'),

    // Create Asset Modal
    btnAddAsset: document.getElementById('btn-add-asset'),
    modalCreateBackdrop: document.getElementById('modal-create-backdrop'),
    btnModalClose: document.getElementById('btn-modal-close'),
    btnCreateCancel: document.getElementById('btn-create-cancel'),
    btnCreateSubmit: document.getElementById('btn-create-submit'),
    createForm: document.getElementById('create-form'),
    newCategory: document.getElementById('new-category'),
    newId: document.getElementById('new-id'),
    newName: document.getElementById('new-name'),
    newSubcategory: document.getElementById('new-subcategory'),
    newStage: document.getElementById('new-stage'),
    newRegion: document.getElementById('new-region'),
    newPurpose: document.getElementById('new-purpose'),
    newForms: document.getElementById('new-forms'),
    newNotes: document.getElementById('new-notes'),

    // Export & Refresh
    btnExport: document.getElementById('btn-export'),
    exportDropdown: document.getElementById('export-dropdown'),
    exportJson: document.getElementById('export-json'),
    exportCsv: document.getElementById('export-csv'),
    btnRefresh: document.getElementById('btn-refresh'),
    toastContainer: document.getElementById('toast-container')
  };

  // Initialize
  async function init() {
    bindEvents();
    await loadData();
  }

  // Fetch API Data
  async function loadData() {
    try {
      el.liveStatus.textContent = '同步中...';
      const resp = await fetch('/api/data');
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();

      state.assets = data.assets || [];
      state.gameplay = data.gameplay || { items: [], characters: [], vessels: [] };
      state.stats = data.stats || {};
      state.mediaCatalog = data.media_catalog || [];

      el.liveStatus.textContent = '本地已联通';
      renderAll();
      showToast('数据同步完成', 'success');
    } catch (err) {
      console.error('Failed to load data:', err);
      el.liveStatus.textContent = '连接中断';
      showToast('加载失败: ' + err.message, 'error');
    }
  }

  // Bind Event Listeners
  function bindEvents() {
    // Nav Tabs
    el.navTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const tabId = tab.dataset.tab;
        switchTab(tabId);
      });
    });

    // Global Search
    el.globalSearch.addEventListener('input', (e) => {
      state.filters.search = e.target.value.trim().toLowerCase();
      renderArtCatalog();
      if (state.activeTab !== 'tab-art' && state.filters.search) {
        switchTab('tab-art');
      }
    });

    // Keyboard Shortcuts
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if (el.modalCreateBackdrop.classList.contains('active')) {
          closeModal();
        } else if (el.assetDrawer.classList.contains('active')) {
          closeDrawer();
        } else if (state.filters.search) {
          el.globalSearch.value = '';
          state.filters.search = '';
          renderArtCatalog();
        }
      }
    });

    // Filter Controls
    el.selectStage.addEventListener('change', (e) => {
      state.filters.stage = e.target.value;
      renderArtCatalog();
    });

    el.selectStatus.addEventListener('change', (e) => {
      state.filters.status = e.target.value;
      renderArtCatalog();
    });

    el.checkHasMedia.addEventListener('change', (e) => {
      state.filters.hasMedia = e.target.checked;
      renderArtCatalog();
    });

    // View Toggles
    el.btnViewGrid.addEventListener('click', () => {
      state.viewMode = 'grid';
      el.btnViewGrid.classList.add('active');
      el.btnViewTable.classList.remove('active');
      el.artGridView.classList.remove('hidden');
      el.artTableView.classList.add('hidden');
    });

    el.btnViewTable.addEventListener('click', () => {
      state.viewMode = 'table';
      el.btnViewTable.classList.add('active');
      el.btnViewGrid.classList.remove('active');
      el.artTableView.classList.remove('hidden');
      el.artGridView.classList.add('hidden');
    });

    // Gameplay Subnav Tabs
    el.subnavBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        el.subnavBtns.forEach(b => b.classList.remove('active'));
        el.subtabPanes.forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const target = document.getElementById(btn.dataset.subtab);
        if (target) target.classList.add('active');
      });
    });

    // Gameplay Items Filter Pills
    el.itemFilterPills.forEach(pill => {
      pill.addEventListener('click', () => {
        el.itemFilterPills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        renderGameplayItems(pill.dataset.itemKind);
      });
    });

    // Drawer Close & Save
    el.btnDrawerClose.addEventListener('click', closeDrawer);
    el.btnDrawerCancel.addEventListener('click', closeDrawer);
    el.drawerOverlay.addEventListener('click', closeDrawer);
    el.btnDrawerSave.addEventListener('click', handleSaveAsset);

    // Modal Create Asset
    el.btnAddAsset.addEventListener('click', openCreateModal);
    el.btnModalClose.addEventListener('click', closeModal);
    el.btnCreateCancel.addEventListener('click', closeModal);
    el.btnCreateSubmit.addEventListener('click', handleCreateAsset);

    // Export Dropdown
    el.btnExport.addEventListener('click', (e) => {
      e.stopPropagation();
      el.btnExport.parentElement.classList.toggle('active');
    });

    document.addEventListener('click', () => {
      document.querySelectorAll('.dropdown').forEach(d => d.classList.remove('active'));
    });

    el.exportJson.addEventListener('click', (e) => {
      e.preventDefault();
      exportDataAsJson();
    });

    el.exportCsv.addEventListener('click', (e) => {
      e.preventDefault();
      exportDataAsCsv();
    });

    el.btnRefresh.addEventListener('click', loadData);

    // Workshop Controls
    el.btnPlayerChecker.addEventListener('click', () => {
      state.workshop.isChecker = !state.workshop.isChecker;
      el.playerViewport.classList.toggle('checkerboard', state.workshop.isChecker);
      el.btnPlayerChecker.textContent = state.workshop.isChecker ? '深色底' : '棋盘格';
    });

    el.btnZoomIn.addEventListener('click', () => setZoom(state.workshop.zoom + 0.25));
    el.btnZoomOut.addEventListener('click', () => setZoom(Math.max(0.25, state.workshop.zoom - 0.25)));
    el.btnZoomFit.addEventListener('click', () => setZoom(1.0));

    el.btnPlayPause.addEventListener('click', togglePlayback);
    el.btnStepNext.addEventListener('click', stepNextFrame);
    el.btnStepPrev.addEventListener('click', stepPrevFrame);
    el.selectFps.addEventListener('change', (e) => {
      state.workshop.fps = parseInt(e.target.value, 10);
      if (state.workshop.isPlaying) {
        togglePlayback();
        togglePlayback();
      }
    });
  }

  // Tab Switcher
  function switchTab(tabId) {
    state.activeTab = tabId;
    el.navTabs.forEach(t => {
      t.classList.toggle('active', t.dataset.tab === tabId);
    });
    el.tabPanes.forEach(pane => {
      pane.classList.toggle('active', pane.id === tabId);
    });

    if (tabId === 'tab-media') {
      renderWorkshop();
    }
  }

  // Render All
  function renderAll() {
    renderDashboard();
    renderCategoryPills();
    renderArtCatalog();
    renderGameplay();
    renderWorkshop();
  }

  // =========================================================================
  // TAB 1: 全景看板 (Dashboard) Render
  // =========================================================================
  function renderDashboard() {
    const stats = state.stats;
    el.statTotal.textContent = stats.total_assets || state.assets.length;
    el.statSlice.textContent = (stats.stage_breakdown && stats.stage_breakdown['切片必需']) || 21;
    el.statMedia.textContent = stats.with_live_media || 0;
    el.statGameplay.textContent = (state.gameplay.items ? state.gameplay.items.length : 20) + (state.gameplay.characters ? state.gameplay.characters.length : 5);

    // Stage Breakdown
    const total = state.assets.length || 1;
    const stageBreakdown = stats.stage_breakdown || {};
    const stages = [
      { name: '切片必需', color: 'cinnabar' },
      { name: '切片候选', color: 'jade' },
      { name: '首版规划', color: '' },
      { name: '后续规划', color: '' },
      { name: '候选未纳入', color: '' }
    ];

    let stageHtml = '';
    stages.forEach(s => {
      const count = stageBreakdown[s.name] || 0;
      const pct = Math.round((count / total) * 100);
      stageHtml += `
        <div class="breakdown-item" data-stage="${s.name}">
          <div class="breakdown-header">
            <span class="breakdown-name">${s.name}</span>
            <span class="breakdown-count">${count} 条 (${pct}%)</span>
          </div>
          <div class="progress-track">
            <div class="progress-bar ${s.color}" style="width: ${pct}%"></div>
          </div>
        </div>
      `;
    });
    el.stageBreakdownList.innerHTML = stageHtml;

    // Status Breakdown
    const statusBreakdown = stats.status_breakdown || {};
    const statuses = Object.keys(statusBreakdown);
    let statusHtml = '';
    statuses.forEach(st => {
      const count = statusBreakdown[st] || 0;
      const pct = Math.round((count / total) * 100);
      statusHtml += `
        <div class="breakdown-item">
          <div class="breakdown-header">
            <span class="breakdown-name">${st}</span>
            <span class="breakdown-count">${count} 条 (${pct}%)</span>
          </div>
          <div class="progress-track">
            <div class="progress-bar jade" style="width: ${pct}%"></div>
          </div>
        </div>
      `;
    });
    el.statusBreakdownList.innerHTML = statusHtml || '<div class="text-muted">无状态数据</div>';

    // Six Vessels Matrix
    renderVesselsMatrix();

    // 13 Category Cards
    renderCategoryCardsGrid();
  }

  function renderVesselsMatrix() {
    const vessels = state.gameplay.vessels || [];
    const vesselColors = {
      '金': 'var(--vessel-gold)',
      '木': 'var(--vessel-wood)',
      '水': 'var(--vessel-water)',
      '火': 'var(--vessel-fire)',
      '土': 'var(--vessel-earth)',
      '雷': 'var(--vessel-thunder)',
      '场': 'var(--bronze-light)'
    };

    let html = '';
    vessels.forEach(v => {
      const color = vesselColors[v.container] || 'var(--bronze-gold)';
      html += `
        <div class="vessel-box" style="border-left: 3px solid ${color};">
          <div class="vessel-badge" style="background: rgba(255,255,255,0.06); color: ${color};">
            <span>● 容器归属: ${v.container}</span>
          </div>
          <div class="vessel-name">${escapeHtml(v.name)}</div>
          <div class="vessel-desc" title="${escapeHtml(v.description)}">${escapeHtml(v.description)}</div>
        </div>
      `;
    });
    el.vesselsMatrix.innerHTML = html;
  }

  function renderCategoryCardsGrid() {
    const catCounts = state.stats.category_breakdown || {};
    let html = '';
    Object.keys(categoryIcons).forEach(cat => {
      const count = catCounts[cat] || 0;
      const icon = categoryIcons[cat] || '📦';
      html += `
        <div class="category-mini-card" data-category="${cat}">
          <div class="category-mini-icon">${icon}</div>
          <div class="category-mini-title">${cat}</div>
          <div class="category-mini-count">${count} 条</div>
        </div>
      `;
    });
    el.categoryCardsGrid.innerHTML = html;

    // Attach click jump
    el.categoryCardsGrid.querySelectorAll('.category-mini-card').forEach(card => {
      card.addEventListener('click', () => {
        const cat = card.dataset.category;
        state.filters.category = cat;
        updatePillSelection();
        switchTab('tab-art');
        renderArtCatalog();
      });
    });
  }

  // =========================================================================
  // TAB 2: 美术需求总库 (Art Catalog) Render
  // =========================================================================
  function renderCategoryPills() {
    const catCounts = state.stats.category_breakdown || {};
    let html = `<button class="pill ${state.filters.category === 'ALL' ? 'active' : ''}" data-category="ALL">全部 (${state.assets.length})</button>`;
    
    Object.keys(categoryIcons).forEach(cat => {
      const count = catCounts[cat] || 0;
      const isActive = state.filters.category === cat ? 'active' : '';
      html += `<button class="pill ${isActive}" data-category="${cat}">${cat} (${count})</button>`;
    });

    el.categoryPills.innerHTML = html;

    el.categoryPills.querySelectorAll('.pill').forEach(pill => {
      pill.addEventListener('click', () => {
        state.filters.category = pill.dataset.category;
        updatePillSelection();
        renderArtCatalog();
      });
    });
  }

  function updatePillSelection() {
    el.categoryPills.querySelectorAll('.pill').forEach(pill => {
      pill.classList.toggle('active', pill.dataset.category === state.filters.category);
    });
  }

  function getFilteredAssets() {
    const f = state.filters;
    return state.assets.filter(a => {
      // Category filter
      if (f.category !== 'ALL' && a['一级分类'] !== f.category) return false;

      // Stage filter
      if (f.stage !== 'ALL' && a['范围阶段'] !== f.stage) return false;

      // Status filter
      if (f.status !== 'ALL' && a['制作状态'] !== f.status) return false;

      // Has media filter
      if (f.hasMedia && (!a.media || a.media.length === 0)) return false;

      // Search filter
      if (f.search) {
        const query = f.search;
        const targetStr = (
          (a['资产ID'] || '') + ' ' +
          (a['资产名称'] || '') + ' ' +
          (a['一级分类'] || '') + ' ' +
          (a['二级分类'] || '') + ' ' +
          (a['地区或环节'] || '') + ' ' +
          (a['用途'] || '') + ' ' +
          (a['所需形态_状态_动作'] || '') + ' ' +
          (a['来源索引'] || '') + ' ' +
          (a['备注'] || '')
        ).toLowerCase();
        if (!targetStr.includes(query)) return false;
      }

      return true;
    });
  }

  function renderArtCatalog() {
    const filtered = getFilteredAssets();
    el.filteredCount.textContent = filtered.length;

    // Render Grid
    renderArtGrid(filtered);

    // Render Table
    renderArtTable(filtered);
  }

  function renderArtGrid(items) {
    if (items.length === 0) {
      el.artGridView.innerHTML = `
        <div style="grid-column: 1 / -1; padding: 4rem 1rem; text-align: center; color: var(--text-muted);">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🔍</div>
          <div>没有找到匹配的资产条目</div>
        </div>
      `;
      return;
    }

    let html = '';
    items.forEach(a => {
      const aid = a['资产ID'];
      const stage = a['范围阶段'] || '首版规划';
      const stageClass = getStageBadgeClass(stage);
      const mediaList = a.media || [];
      const hasMedia = mediaList.length > 0;
      const cat = a['一级分类'] || '人物';
      const icon = categoryIcons[cat] || '📦';

      let mediaHtml = '';
      if (hasMedia) {
        const firstMedia = mediaList[0];
        mediaHtml = `
          <div class="card-media-preview" data-asset-id="${aid}">
            <img src="/media/${encodeURIComponent(firstMedia.path)}" alt="${aid}" loading="lazy">
            <span class="media-count-tag">${mediaList.length} 件素材切片</span>
          </div>
        `;
      } else {
        mediaHtml = `
          <div class="card-media-preview card-media-empty" data-asset-id="${aid}">
            <span style="font-size: 2.2rem; opacity: 0.35;">${icon}</span>
            <span>待制作素材 / 需求登记</span>
          </div>
        `;
      }

      html += `
        <div class="asset-card" data-asset-id="${aid}">
          <div class="card-top-bar">
            <span class="card-id-badge">${aid}</span>
            <span class="stage-badge ${stageClass}">${stage}</span>
          </div>
          <div class="card-title">${escapeHtml(a['资产名称'] || '未命名')}</div>
          <div class="card-subline">
            <span>${cat} · ${escapeHtml(a['二级分类'] || '')}</span>
            <span>•</span>
            <span>${escapeHtml(a['地区或环节'] || '全域')}</span>
          </div>
          ${mediaHtml}
          <div class="card-body-text" title="${escapeHtml(a['所需形态_状态_动作'] || a['用途'] || '')}">
            ${escapeHtml(a['所需形态_状态_动作'] || a['用途'] || '暂无详细描述')}
          </div>
          <div class="card-footer-tags">
            <span class="status-tag ${hasMedia ? 'active' : ''}">
              <span>●</span>
              ${escapeHtml(a['制作状态'] || '仅登记，未制作')}
            </span>
            <button class="card-action-btn" data-action="edit" data-asset-id="${aid}">详情与编辑 →</button>
          </div>
        </div>
      `;
    });

    el.artGridView.innerHTML = html;

    // Attach card event listeners
    el.artGridView.querySelectorAll('.asset-card').forEach(card => {
      card.addEventListener('click', (e) => {
        const aid = card.dataset.assetId;
        openDrawer(aid);
      });
    });
  }

  function renderArtTable(items) {
    if (items.length === 0) {
      el.artTableBody.innerHTML = `<tr><td colspan="10" style="text-align: center; padding: 2rem;">没有匹配的资产</td></tr>`;
      return;
    }

    let html = '';
    items.forEach(a => {
      const aid = a['资产ID'];
      const stage = a['范围阶段'] || '首版规划';
      const stageClass = getStageBadgeClass(stage);
      const mediaList = a.media || [];
      const hasMedia = mediaList.length > 0;

      html += `
        <tr>
          <td><span class="card-id-badge">${aid}</span></td>
          <td>${escapeHtml(a['一级分类'] || '')}</td>
          <td>${escapeHtml(a['二级分类'] || '')}</td>
          <td><strong>${escapeHtml(a['资产名称'] || '')}</strong></td>
          <td>${escapeHtml(a['地区或环节'] || '')}</td>
          <td><div style="max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHtml(a['所需形态_状态_动作'] || a['用途'] || '')}">${escapeHtml(a['所需形态_状态_动作'] || a['用途'] || '')}</div></td>
          <td><span class="stage-badge ${stageClass}">${stage}</span></td>
          <td><span class="status-tag ${hasMedia ? 'active' : ''}">${escapeHtml(a['制作状态'] || '仅登记，未制作')}</span></td>
          <td>${hasMedia ? `<span style="color: var(--patina-jade); font-weight: 600;">${mediaList.length} 件</span>` : '<span style="color: var(--text-muted);">-</span>'}</td>
          <td>
            <button class="card-action-btn" data-action="edit" data-asset-id="${aid}">编辑</button>
          </td>
        </tr>
      `;
    });

    el.artTableBody.innerHTML = html;

    el.artTableBody.querySelectorAll('.card-action-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        openDrawer(btn.dataset.assetId);
      });
    });
  }

  function getStageBadgeClass(stage) {
    if (stage === '切片必需') return 'slice-need';
    if (stage === '切片候选') return 'slice-cand';
    if (stage === '首版规划') return 'first-version';
    if (stage === '后续规划') return 'future';
    return 'candidate';
  }

  // =========================================================================
  // TAB 3: 六器与玩法构筑 (Gameplay) Render
  // =========================================================================
  function renderGameplay() {
    renderGameplayCharacters();
    renderGameplaySkills();
    renderGameplayItems('ALL');
    renderGameplayVessels();
  }

  function renderGameplayCharacters() {
    const chars = state.gameplay.characters || [];
    let html = '';
    chars.forEach(c => {
      html += `
        <div class="gameplay-card">
          <div class="gameplay-card-header">
            <div class="gameplay-name">${escapeHtml(c.name)}</div>
            <span class="gameplay-kind-badge">${escapeHtml(c.kind || '人物职责')}</span>
          </div>
          <div class="gameplay-desc">${escapeHtml(c.description || '')}</div>
        </div>
      `;
    });
    el.gameplayCharsGrid.innerHTML = html || '<div class="text-muted">暂无角色数据</div>';
  }

  function renderGameplaySkills() {
    // Skills from CONTENT where type is '技能书'
    const skills = (state.gameplay.items || []).filter(i => i.kind === '技能书');
    let html = '';
    skills.forEach(s => {
      html += `
        <div class="gameplay-card" style="border-left: 3px solid var(--bronze-gold);">
          <div class="gameplay-card-header">
            <div class="gameplay-name">${escapeHtml(s.name)}</div>
            <span class="gameplay-kind-badge">技能书 · ${s.width}×${s.height}格</span>
          </div>
          <div class="gameplay-desc">${escapeHtml(s.description || '')}</div>
        </div>
      `;
    });
    el.gameplaySkillsGrid.innerHTML = html || '<div class="text-muted">暂无技能书数据</div>';
  }

  function renderGameplayItems(filterKind) {
    let items = state.gameplay.items || [];
    if (filterKind !== 'ALL') {
      items = items.filter(i => i.kind === filterKind);
    }

    let html = '';
    items.forEach(it => {
      html += `
        <div class="gameplay-card">
          <div class="gameplay-card-header">
            <div class="gameplay-name" style="font-size: 1.05rem;">${escapeHtml(it.name)}</div>
            <span class="gameplay-kind-badge">${escapeHtml(it.kind)} · ${it.container ? `[${it.container}]` : ''} ${it.width}×${it.height}</span>
          </div>
          <div class="gameplay-desc" style="font-size: 0.82rem;">${escapeHtml(it.description || '')}</div>
        </div>
      `;
    });
    el.gameplayItemsGrid.innerHTML = html || '<div class="text-muted">暂无物品构筑数据</div>';
  }

  function renderGameplayVessels() {
    const vessels = state.gameplay.vessels || [];
    let html = '';
    vessels.forEach(v => {
      html += `
        <div class="gameplay-card" style="border-top: 3px solid var(--bronze-gold);">
          <div class="gameplay-card-header">
            <div class="gameplay-name">${escapeHtml(v.name)}</div>
            <span class="gameplay-kind-badge">容器归属: ${escapeHtml(v.container)}</span>
          </div>
          <div class="gameplay-desc">${escapeHtml(v.description || '')}</div>
        </div>
      `;
    });
    el.gameplayVesselsGrid.innerHTML = html;
  }

  // =========================================================================
  // TAB 4: 现役素材工坊 (Media Workshop) Render
  // =========================================================================
  function renderWorkshop() {
    // Find all assets with media
    const assetsWithMedia = state.assets.filter(a => a.media && a.media.length > 0);
    
    if (assetsWithMedia.length === 0) {
      el.workshopAssetList.innerHTML = '<div style="color: var(--text-muted); font-size: 0.8rem;">暂未发现素材文件</div>';
      return;
    }

    if (!state.workshop.activeAssetId) {
      state.workshop.activeAssetId = assetsWithMedia[0]['资产ID'];
    }

    let listHtml = '';
    assetsWithMedia.forEach(a => {
      const aid = a['资产ID'];
      const isActive = aid === state.workshop.activeAssetId ? 'active' : '';
      listHtml += `
        <div class="workshop-asset-item ${isActive}" data-asset-id="${aid}">
          <span class="item-id">${aid}</span>
          <span class="item-name">${escapeHtml(a['资产名称'])}</span>
        </div>
      `;
    });
    el.workshopAssetList.innerHTML = listHtml;

    el.workshopAssetList.querySelectorAll('.workshop-asset-item').forEach(item => {
      item.addEventListener('click', () => {
        state.workshop.activeAssetId = item.dataset.assetId;
        state.workshop.activeMediaIndex = 0;
        renderWorkshop();
      });
    });

    // Render active asset media in player
    const activeAsset = state.assets.find(a => a['资产ID'] === state.workshop.activeAssetId);
    if (!activeAsset || !activeAsset.media || activeAsset.media.length === 0) return;

    el.playerAssetId.textContent = activeAsset['资产ID'];
    el.playerAssetName.textContent = activeAsset['资产名称'];

    const currentMedia = activeAsset.media[state.workshop.activeMediaIndex] || activeAsset.media[0];
    el.playerFilename.textContent = currentMedia.filename;
    el.playerImg.src = `/media/${encodeURIComponent(currentMedia.path)}`;

    // Render variations thumbnails
    let thumbsHtml = '';
    activeAsset.media.forEach((m, idx) => {
      const isSel = idx === state.workshop.activeMediaIndex ? 'active' : '';
      thumbsHtml += `
        <div class="thumb-item ${isSel}" data-index="${idx}" title="${escapeHtml(m.filename)}">
          <img src="/media/${encodeURIComponent(m.path)}" alt="${idx}">
        </div>
      `;
    });
    el.mediaThumbnailsStrip.innerHTML = thumbsHtml;

    el.mediaThumbnailsStrip.querySelectorAll('.thumb-item').forEach(th => {
      th.addEventListener('click', () => {
        state.workshop.activeMediaIndex = parseInt(th.dataset.index, 10);
        renderWorkshop();
      });
    });
  }

  function setZoom(val) {
    state.workshop.zoom = Math.round(val * 100) / 100;
    el.zoomText.textContent = `${Math.round(state.workshop.zoom * 100)}%`;
    el.viewportCanvasWrap.style.transform = `scale(${state.workshop.zoom})`;
  }

  function togglePlayback() {
    state.workshop.isPlaying = !state.workshop.isPlaying;
    el.btnPlayPause.innerHTML = state.workshop.isPlaying
      ? `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg>`
      : `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>`;

    if (state.workshop.isPlaying) {
      const interval = Math.round(1000 / state.workshop.fps);
      state.workshop.timer = setInterval(() => {
        stepNextFrame();
      }, interval);
    } else {
      clearInterval(state.workshop.timer);
      state.workshop.timer = null;
    }
  }

  function stepNextFrame() {
    const activeAsset = state.assets.find(a => a['资产ID'] === state.workshop.activeAssetId);
    if (!activeAsset || !activeAsset.media) return;
    const len = activeAsset.media.length;
    if (len <= 1) return;
    state.workshop.activeMediaIndex = (state.workshop.activeMediaIndex + 1) % len;
    renderWorkshop();
  }

  function stepPrevFrame() {
    const activeAsset = state.assets.find(a => a['资产ID'] === state.workshop.activeAssetId);
    if (!activeAsset || !activeAsset.media) return;
    const len = activeAsset.media.length;
    if (len <= 1) return;
    state.workshop.activeMediaIndex = (state.workshop.activeMediaIndex - 1 + len) % len;
    renderWorkshop();
  }

  // =========================================================================
  // Asset Drawer & Edit Engine
  // =========================================================================
  function openDrawer(aid) {
    const asset = state.assets.find(a => a['资产ID'] === aid);
    if (!asset) return;

    state.selectedAsset = asset;
    el.drawerId.textContent = asset['资产ID'];
    el.drawerName.textContent = asset['资产名称'] || '未命名资产';

    el.editCategory.value = asset['一级分类'] || '';
    el.editSubcategory.value = asset['二级分类'] || '';
    el.editStage.value = asset['范围阶段'] || '首版规划';
    el.editStatus.value = asset['制作状态'] || '仅登记，未制作';
    el.editRegion.value = asset['地区或环节'] || '';
    el.editPurpose.value = asset['用途'] || '';
    el.editForms.value = asset['所需形态_状态_动作'] || '';
    el.editBasis.value = asset['依据状态'] || '';
    el.editSource.value = asset['来源索引'] || '';
    el.editReuse.value = asset['复用或关联资产'] || '';
    el.editNotes.value = asset['备注'] || '';

    // Render media previews inside drawer
    const mediaList = asset.media || [];
    if (mediaList.length > 0) {
      el.drawerMediaSection.style.display = 'block';
      let mHtml = '';
      mediaList.forEach(m => {
        mHtml += `
          <div class="drawer-media-item" title="${escapeHtml(m.filename)}">
            <img src="/media/${encodeURIComponent(m.path)}" alt="${m.filename}">
          </div>
        `;
      });
      el.drawerMediaGallery.innerHTML = mHtml;
    } else {
      el.drawerMediaSection.style.display = 'none';
      el.drawerMediaGallery.innerHTML = '';
    }

    el.assetDrawer.classList.add('active');
    el.drawerOverlay.classList.add('active');
  }

  function closeDrawer() {
    el.assetDrawer.classList.remove('active');
    el.drawerOverlay.classList.remove('active');
    state.selectedAsset = null;
  }

  async function handleSaveAsset() {
    if (!state.selectedAsset) return;
    const aid = state.selectedAsset['资产ID'];

    const updatePayload = {
      '资产ID': aid,
      '一级分类': el.editCategory.value,
      '二级分类': el.editSubcategory.value,
      '范围阶段': el.editStage.value,
      '制作状态': el.editStatus.value,
      '地区或环节': el.editRegion.value,
      '用途': el.editPurpose.value,
      '所需形态_状态_动作': el.editForms.value,
      '依据状态': el.editBasis.value,
      '来源索引': el.editSource.value,
      '复用或关联资产': el.editReuse.value,
      '备注': el.editNotes.value
    };

    try {
      el.btnDrawerSave.disabled = true;
      el.btnDrawerSave.textContent = '正在同步保存...';

      const resp = await fetch('/api/asset/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatePayload)
      });
      const res = await resp.json();
      if (!res.success) throw new Error(res.error || '保存失败');

      // Update in local state
      Object.assign(state.selectedAsset, updatePayload);
      closeDrawer();
      renderAll();
      showToast(res.message || '资产保存成功', 'success');
    } catch (err) {
      showToast('保存失败: ' + err.message, 'error');
    } finally {
      el.btnDrawerSave.disabled = false;
      el.btnDrawerSave.textContent = '一键同步保存 (Save & Sync)';
    }
  }

  // =========================================================================
  // Create Asset Modal
  // =========================================================================
  function openCreateModal() {
    el.createForm.reset();
    el.modalCreateBackdrop.classList.add('active');
  }

  function closeModal() {
    el.modalCreateBackdrop.classList.remove('active');
  }

  async function handleCreateAsset() {
    const name = el.newName.value.trim();
    if (!name) {
      showToast('请填写资产名称！', 'error');
      el.newName.focus();
      return;
    }

    const payload = {
      '资产ID': el.newId.value.trim(),
      '一级分类': el.newCategory.value,
      '二级分类': el.newSubcategory.value.trim(),
      '资产名称': name,
      '地区或环节': el.newRegion.value.trim() || '全域',
      '范围阶段': el.newStage.value,
      '用途': el.newPurpose.value.trim(),
      '所需形态_状态_动作': el.newForms.value.trim(),
      '备注': el.newNotes.value.trim(),
      '制作状态': '仅登记，未制作'
    };

    try {
      el.btnCreateSubmit.disabled = true;
      el.btnCreateSubmit.textContent = '创建中...';

      const resp = await fetch('/api/asset/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const res = await resp.json();
      if (!res.success) throw new Error(res.error || '创建失败');

      closeModal();
      await loadData();
      showToast(res.message || '新资产创建成功', 'success');
    } catch (err) {
      showToast('创建失败: ' + err.message, 'error');
    } finally {
      el.btnCreateSubmit.disabled = false;
      el.btnCreateSubmit.textContent = '确认创建并同步';
    }
  }

  // =========================================================================
  // Data Export
  // =========================================================================
  function exportDataAsJson() {
    const raw = {
      schema_version: '0.1',
      project: '九鼎',
      sub_ip: '十日',
      date: new Date().toISOString().slice(0, 10),
      purpose: '资产管理中心快照导出',
      record_count: state.assets.length,
      assets: state.assets
    };
    const blob = new Blob([JSON.stringify(raw, null, 2)], { type: 'application/json' });
    downloadBlob(blob, `九鼎_资产总表_导出_${new Date().toISOString().slice(0, 10)}.json`);
    showToast('JSON 快照导出完成', 'success');
  }

  function exportDataAsCsv() {
    const fields = [
      '资产ID', '一级分类', '二级分类', '资产名称', '地区或环节', '用途',
      '所需形态_状态_动作', '范围阶段', '依据状态', '来源索引',
      '复用或关联资产', '制作状态', '备注'
    ];
    let csv = '\uFEFF' + fields.join(',') + '\n';
    state.assets.forEach(a => {
      const row = fields.map(f => {
        let val = (a[f] || '').toString().replace(/"/g, '""');
        if (val.includes(',') || val.includes('\n') || val.includes('"')) {
          val = `"${val}"`;
        }
        return val;
      });
      csv += row.join(',') + '\n';
    });
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    downloadBlob(blob, `九鼎_资产总表_导出_${new Date().toISOString().slice(0, 10)}.csv`);
    showToast('CSV 文件导出完成', 'success');
  }

  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // Toast System
  function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
      <span>${type === 'success' ? '✔' : '✖'}</span>
      <span>${escapeHtml(message)}</span>
    `;
    el.toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3200);
  }

  // Helper: Escape HTML
  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // Bootstrap
  document.addEventListener('DOMContentLoaded', init);

})();
